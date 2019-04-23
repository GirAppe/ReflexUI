//
//  ViewController.swift
//  ReflexUI
//
//  Created by Andrzej Michnia on 04/23/2019.
//  Copyright (c) 2019 Andrzej Michnia. All rights reserved.
//

import UIKit
import CoreMotion

class ViewController: UIViewController {

    @IBOutlet weak var containerView: TestView!
    @IBOutlet weak var testLabel: ReflexLabel!

    var manager: CMMotionManager!
    var timer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()

        start()
    }

    deinit {
        manager.isGyroActive ? manager.stopGyroUpdates() : ()
        timer?.invalidate()
    }

    // MARK: - Setup

    func start() {
        manager = CMMotionManager()
        guard manager.isGyroAvailable else { return }

        manager.startDeviceMotionUpdates()
        timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateReflex()
            }
        }
    }

    func updateReflex() {
        guard let motion = manager.deviceMotion else { return }

        let pitch = motion.attitude.pitch
        let roll = motion.attitude.roll
//        let yaw = motion.attitude.yaw

        testLabel.offset = CGFloat(pitch + roll)
//        testLabel.angle = CGFloat(motion.attitude.yaw)
//        testLabel.scatter = CGFloat(1.0 + pitch)
//
//        print("\(pitch) \(roll) \(yaw)")
    }

    // MARK: - Actions

    @IBAction func updateOffset(_ sender: UISlider) {
        containerView.offset = CGFloat(sender.value)
        testLabel.offset = CGFloat(sender.value)
    }
    
    @IBAction func updateAngle(_ sender: UISlider) {
        containerView.angle = CGFloat(sender.value)
        testLabel.angle = CGFloat(sender.value)
    }
}

class TestView: UIView {

    var reflexLayer = ReflexLayer()

    var offset: CGFloat {
        get { return reflexLayer.offset }
        set { reflexLayer.offset = newValue }
    }
    var angle: CGFloat {
        get { return reflexLayer.angle }
        set { reflexLayer.angle = newValue }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        let label = UILabel(frame: self.bounds)
        label.text = "GLOSS"
        label.font = UIFont.systemFont(ofSize: 32, weight: .black)
        label.textColor = .black
        layer.addSublayer(reflexLayer)
        addSubview(label)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        layer.backgroundColor = UIColor.red.cgColor
        layer.mask = reflexLayer
        reflexLayer.opacity = 0.4
        reflexLayer.frame = self.bounds
        reflexLayer.updateSize()
    }
}

class ReflexLabel: UILabel {

    // MARK: - Properties
    lazy var gloss: UILabel = {
        let label = UILabel(frame: bounds)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        return label
    }()

    private var reflexLayer = ReflexLayer()

    var offset: CGFloat {
        get { return reflexLayer.offset }
        set { reflexLayer.offset = newValue }
    }
    var angle: CGFloat {
        get { return reflexLayer.angle }
        set { reflexLayer.angle = newValue }
    }
    var scatter: CGFloat {
        get { return reflexLayer.angle }
        set { reflexLayer.scatter = newValue }
    }

    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    // MARK: - Setup

    private func setup() {
        NSLayoutConstraint.activate([
            gloss.topAnchor.constraint(equalTo: topAnchor),
            gloss.bottomAnchor.constraint(equalTo: bottomAnchor),
            gloss.leftAnchor.constraint(equalTo: leftAnchor),
            gloss.rightAnchor.constraint(equalTo: rightAnchor)
        ])

        gloss.font = self.font
        gloss.text = self.text
        gloss.textColor = #colorLiteral(red: 0.1411764771, green: 0.3960784376, blue: 0.5647059083, alpha: 1)

        gloss.layer.addSublayer(reflexLayer)
        gloss.layer.mask = reflexLayer
        reflexLayer.frame = bounds
    }

    // MARK: - Actions

    func update() {

    }
}

class ReflexLayer: CALayer {

    let rotatingLayer = CALayer()
    let reflectLayer = CAGradientLayer()
    let blinkLayer = CAReplicatorLayer()

    var offset: CGFloat {
        get { return _offset }
        set { updateOffset(newValue) }
    }
    var angle: CGFloat = 0 {
        didSet { updatePosition() }
    }
    var scatter: CGFloat = 1.0

    private var _offset: CGFloat = 0
    private var bound: CGFloat {
        return sqrt(bounds.height * bounds.height + bounds.width * bounds.width)
    }
    private lazy var setupOnce: () -> Void = {
        setup()
        return {}
    }()

    // MARK: - Lifecycle

    override func layoutSublayers() {
        super.layoutSublayers()
        setupOnce()
    }

    // MARK: - Setup

    private func setup() {
        rotatingLayer.frame = bounds
        addSublayer(rotatingLayer)

        reflectLayer.frame = CGRect(x: 0, y: 0, width: bound, height: bound)
        reflectLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.black.cgColor,
            UIColor.clear.cgColor
        ]
        reflectLayer.startPoint = CGPoint.zero
        reflectLayer.endPoint = CGPoint(x: 1, y: 0)
//        reflectLayer.locations = [
//            NSNumber(value: 0.0),
//            NSNumber(value: 0.2),
//            NSNumber(value: 0.5),
//            NSNumber(value: 0.8),
//            NSNumber(value: 1.0)
//        ]

        blinkLayer.frame = CGRect(x: 0, y: 0, width: bound, height: bound)
        blinkLayer.addSublayer(reflectLayer)
        blinkLayer.instanceCount = 2
        blinkLayer.instanceTransform = CATransform3DMakeTranslation(bound * scatter, 0, 0)

        rotatingLayer.addSublayer(blinkLayer)

        updateSize()
        updatePosition()
    }

    private func updateOffset(_ offset: CGFloat) {
        guard offset >= 0 else { return updateOffset(offset + 1) }
        guard offset < 1 else { return updateOffset(offset - 1) }

        _offset = offset
        updatePosition()
        display()
    }

    private func updatePosition() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let translate = CGAffineTransform.identity
            .translatedBy(x: -_offset * bound * scatter, y: 0)
            .translatedBy(x: -(bound - bounds.width) / 2, y: -(bound - bounds.height) / 2)
        blinkLayer.transform = CATransform3DMakeAffineTransform(translate)
        let rotate = CGAffineTransform.identity.rotated(by: angle)
        rotatingLayer.transform = CATransform3DMakeAffineTransform(rotate)
        CATransaction.commit()
    }

    func updateSize() {
        reflectLayer.bounds = CGRect(x: 0, y: 0, width: bound, height: bound)
        blinkLayer.bounds = CGRect(x: 0, y: 0, width: bound, height: bound)
        rotatingLayer.bounds = bounds
        blinkLayer.instanceTransform = CATransform3DMakeTranslation(bound * scatter, 0, 0)
    }
}
