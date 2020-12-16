//
//  ViewController.swift
//  GyroscopeTransferData
//
//  Created by Krzysztof Kogut on 03/11/2020.
//

import UIKit
import CoreMotion
import SwiftSocket

class ViewController: UIViewController {
    
    // MARK: - Constants
    let maxPortValueLength = 5
    
    // MARK: - IBOutlets
    @IBOutlet weak var addressTextField: UITextField!
    @IBOutlet weak var portTextField: UITextField!
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var historyTextView: UITextView!
    
    @IBOutlet weak var intervalTextField: UITextField!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var sendMessageViewBottomConstraint: NSLayoutConstraint!
    
    // MARK: - Variables
    var client: TCPClient!
    var isConnected: Bool = false
    
    var outputStream: OutputStream!
    
    let motionManager = CMMotionManager()
    var timer: Timer!
    
    var isStartTime: Bool = true
    
    var interval: Double = 1.0 / 5.0
    var dt: Double = 0.0
    var newTimestamp: Double = 0.0
    var lastTimestamp: Double = 0.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        startButton.isEnabled = true
        prepopulateValues()
        addressTextField.becomeFirstResponder()
        
        addressTextField.addTarget(self, action: #selector(textFieldDidChange), for: UIControl.Event.editingChanged)
        portTextField.addTarget(self, action: #selector(textFieldDidChange), for: UIControl.Event.editingChanged)
        
        setupStatusTextView()
        setupTextFields()
    }
    
    // MARK: - IBActions
    @IBAction func connectButtonClicked(_ sender: UIButton) {
        if isConnected {
            disconnectFromClient()
        } else {
            connectToClient()
        }
    }
    
    @IBAction func startButtonClicked(_ sender: Any) {
        historyTextView.text = ""
        if let newInterval = Double(intervalTextField.text!) {
            interval = newInterval
        }
        startDeviceMotion()
    }
    
    // MARK: - Private Methods
    private func setupStatusTextView() {
        historyTextView.layoutManager.allowsNonContiguousLayout = false
        
        historyTextView.layer.borderColor = UIColor.lightGray.cgColor
        historyTextView.layer.borderWidth = 0.25
        historyTextView.layer.cornerRadius = 5
    }
    
    private func setupTextFields() {
        addressTextField.delegate = self
        portTextField.delegate = self
    }
    
    @objc dynamic private func keyboardWillShow(_ notification: Notification) {
        let info = notification.userInfo!
        let keyboardFrame = (info[UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        sendMessageViewBottomConstraint.constant = keyboardFrame.height + 10
    }
    
    @objc dynamic private func keyboardWillHide(_ notification: Notification) {
        sendMessageViewBottomConstraint.constant = 15
    }
    
    @objc dynamic private func textFieldDidChange(textField: UITextField) {
        connectButton.isEnabled = hasHostValues()
    }
    
    private func hasHostValues() -> Bool {
        return (addressTextField.text ?? "").count > 0 && (portTextField.text ?? "").count > 0
    }
    
    private func connectToClient() {
        let address = addressTextField.text ?? getValue(forKey: "address")
        let port = Int32(portTextField.text ?? getValue(forKey: "port"))
        
        client = TCPClient(address: address, port: port!)
        
        switch client.connect(timeout: 5) {
        case .success:
            isConnected = true
            saveEnteredValues()
            updateUIFor(connectedStatus: isConnected)
            receiveMessage()
            
        case .failure(let error):
            addToHistory("Failed: \(error)")
        }
    }
    
    private func disconnectFromClient() {
        client.close()
        
        isConnected = false
        updateUIFor(connectedStatus: isConnected)
    }
    
    private func updateUIFor(connectedStatus: Bool) {
        DispatchQueue.main.async {
            self.startButton.isEnabled = true
            
            if connectedStatus {
                self.addToHistory("Connected!")
                self.connectButton.setTitle("Disconnect", for: .normal)
            } else {
                self.addToHistory("Disconnected!")
                self.connectButton.setTitle("Connect", for: .normal)
            }
        }
    }
    
    private func receiveMessage() {
        DispatchQueue.global(qos: .background).async {
            while true {
                guard let data = self.client.read(1024*10, timeout: 100) else { return }
                
                DispatchQueue.main.async {
                    if let response = String(bytes: data, encoding: .utf8) {
                        self.addToHistory("Server: \(response)")
                    }
                }
            }
        }
    }
    
    private func send(stringToSend: String) {
        switch client.send(string: stringToSend) {
        case .success:
            print(stringToSend)
        case .failure(let error):
            print("Failed to send with \(error)")
        }
    }
    
    private func prepopulateValues() {
        addressTextField.text = getValue(forKey: "address")
        portTextField.text = getValue(forKey: "port")
        connectButton.isEnabled = hasHostValues()
    }
    
    private func saveEnteredValues() {
        set(addressTextField.text ?? "", forKey: "address")
        set(portTextField.text ?? "", forKey: "port")
    }
    
    private func addToHistory(_ message: String) {
        historyTextView.insertText("\(message)\n")
        let bottom = NSMakeRange(historyTextView.text.count, 1)
        historyTextView.scrollRangeToVisible(bottom)
    }
    
    private func set(_ value: String, forKey: String) {
        UserDefaults.standard.setValue(value, forKey: forKey)
    }
    
    private func getValue(forKey: String) -> String {
        return UserDefaults.standard.string(forKey: forKey) ?? ""
    }
}

// MARK: - UITextFieldDelegate
extension ViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == portTextField {
            connectButtonClicked(connectButton)
        } else if textField == addressTextField {
            portTextField.becomeFirstResponder()
        }
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if textField == portTextField {
            if string.count > 0 && (textField.text ?? "").count >= maxPortValueLength {
                return false
            }
        }
        return true
    }
    
    func startDeviceMotion() {
        if motionManager.isDeviceMotionAvailable {
            self.motionManager.deviceMotionUpdateInterval = interval
            self.motionManager.showsDeviceMovementDisplay = true
            self.motionManager.startAccelerometerUpdates()
            self.motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical)
            // Configure a timer to fetch the motion data.
            self.timer = Timer(fire: Date(), interval: (interval), repeats: true,
                               block: { (timer) in
                                if let data = self.motionManager.deviceMotion {
                                    // Get the attitude relative to the magnetic north reference frame.
                                    let pitch = data.attitude.pitch
                                    let roll = data.attitude.roll
                                    let yaw = data.attitude.yaw
                                    
                                    let quaterionX = data.attitude.quaternion.x
                                    let quaterionY = data.attitude.quaternion.y
                                    let quaterionZ = data.attitude.quaternion.z
                                    let quaterionW = data.attitude.quaternion.w
                                    
                                    // Use the motion data in your app.
                                    let dataToSend = [pitch, roll, yaw, quaterionX, quaterionY, quaterionZ, quaterionW]
                                    self.send(stringToSend: "\(dataToSend)")
                                    self.historyTextView.text = ""
                                    self.addToHistory("Pitch: \(pitch)")
                                    self.addToHistory("Roll: \(roll)")
                                    self.addToHistory("Yaw: \(yaw)")
                                    self.addToHistory("Quaterion x: \(quaterionX)")
                                    self.addToHistory("Quaterion y: \(quaterionY)")
                                    self.addToHistory("Quaterion z: \(quaterionZ)")
                                    self.addToHistory("Quaterion w: \(quaterionW)")
                                }
                               })
            // Add the timer to the current run loop.
            RunLoop.current.add(self.timer!, forMode: RunLoop.Mode.default)
        }
    }
}
