
//
//  ScanViewController.swift
//  Audio Processor
//
//  Created by Matthew Jeng on 7/26/18.
//  Copyright © 2018 Matthew Jeng. All rights reserved.
//

import UIKit
import AVFoundation
import AudioKit
import AudioKitUI
import CoreBluetooth
import Alamofire

class ScanViewController: UIViewController, AVAudioRecorderDelegate,
AVAudioPlayerDelegate, CBPeripheralManagerDelegate {

    var numAudioFilesPosted = 0

    var contralateralScanViewModel = ScanViewModel()
    var suspectedScanViewModel = ScanViewModel()

    @IBOutlet weak var suspectedStatusLabel: UILabel!
    @IBOutlet weak var contralateralStatusLabel: UILabel!
    @IBOutlet weak var suspectedBackgroundView: UIView!
    @IBOutlet weak var contralateralBackgroundView: UIView!

    // how long each recording should be
    var recordingSeconds = 15.0
    
    @IBOutlet weak var trackIdSegControl: UISegmentedControl!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var buttonStackView: UIStackView!
    @IBOutlet weak var contralateralButton: UIButton!
    @IBOutlet weak var suspectedButton: UIButton!
    @IBOutlet weak var suspectedStackView: UIStackView!
    @IBOutlet weak var contralateralStackView: UIStackView!
    @IBOutlet weak var audioPlot: EZAudioPlot!

    // stuff for the audio viz
    var mic: AKMicrophone!
    var tracker: AKFrequencyTracker!
    var silence: AKBooster!
    
    var isUsingBluetooth = false
    var hasReceiviedInitialMessage = false
    
    var peripheralManager: CBPeripheralManager?
    var peripheral: CBPeripheral!
    private var consoleAsciiText: NSAttributedString? = NSAttributedString(string: "")
    
    var isRecording = false
    var audioRecorder: AVAudioRecorder?
    var player : AVAudioPlayer?
    var recordingExists = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AudioKit.output = silence
        do {
            try AudioKit.start()
        } catch {
            AKLog("AudioKit did not start!")
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // peripheralManager?.stopAdvertising()
        // self.peripheralManager = nil
        super.viewDidDisappear(animated)
        if let viewWithTag = view.viewWithTag(100) {
            viewWithTag.removeFromSuperview()
        }
        NotificationCenter.default.removeObserver(self)
        mic.disconnectOutput()
        audioRecorder?.stop()
        tracker.stop()
        silence.stop()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        titleLabel.text = Strings.CONTRALATERAL_READY_TITLE
        // set up scan view models
        contralateralScanViewModel = ScanViewModel(fileName: "audio1",
                                                   location: .Contralateral,
                                                   progressLabel: contralateralStatusLabel,
                                                   playbackButton: contralateralStackView.arrangedSubviews[1] as! UIButton, bgView: contralateralBackgroundView, deleteButton: contralateralStackView.arrangedSubviews[2] as! UIButton, selectButton: contralateralButton)
        
        suspectedScanViewModel = ScanViewModel(fileName: "audio2",
                                               location: .Suspected,
                                               progressLabel: suspectedStatusLabel,
                                               playbackButton: suspectedStackView.arrangedSubviews[1] as! UIButton, bgView: suspectedBackgroundView, deleteButton: suspectedStackView.arrangedSubviews[2] as! UIButton, selectButton: contralateralButton)
        
    
        // audiokit
        AKSettings.audioInputEnabled = true
        
        recordingExists = false
        isRecording = false
        numAudioFilesPosted = 0
        
        mic = AKMicrophone()
        tracker = AKFrequencyTracker(mic)
        silence = AKBooster(tracker, gain: 0)
        
        // Asking user permission for accessing Microphone
        AVAudioSession.sharedInstance().requestRecordPermission () {
            [unowned self] allowed in
            if allowed {
                // Microphone allowed, do what you like!
                
            } else {
                // User denied microphone. Tell them off!
            }
        }
        
        if isUsingBluetooth {
            peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        }
        
        updateUI()
        setupPlot()
        createNotificationForDataFromArduino()
    }
    
    func setupPlot() {
        let plot = AKNodeOutputPlot(mic, frame: audioPlot.bounds)
        plot.plotType = .rolling
        plot.shouldFill = true
        plot.shouldMirror = true
        plot.color = UIColor.blue
        plot.tag = 100
        audioPlot.addSubview(plot)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    @IBAction func contralateralAction(_ sender: UIButton) {
        suspectedScanViewModel.isSelected = false
        contralateralScanViewModel.isSelected = true
        updateUI()
    }
    
    @IBAction func suspectedAction(_ sender: UIButton) {
        suspectedScanViewModel.isSelected = true
        contralateralScanViewModel.isSelected = false
        updateUI()
    }
    
    func updateUI() {
        for scanState in [contralateralScanViewModel, suspectedScanViewModel] {
            
            if scanState.isSelected {
                scanState.bgView.backgroundColor = Colors.SELECTED_BTN
                
            } else {
                UIView.animate(withDuration: 0.5, animations: {
                scanState.bgView.backgroundColor = Colors.DESELECTED_BTN
                })
            }
            switch scanState.progress {
            case .scanInProgress:
                titleLabel.text = scanState.location.rawValue + Strings.SCANNING_TITLE
                scanState.progressLabel.text = Strings.SCANNING
                UIView.animate(withDuration: 0.5, animations: {
                    scanState.bgView.backgroundColor = Colors.CANCEL_BTN
                })
                
            case .scanCancelled:
                scanState.progressLabel.text = Strings.CANCELLED
            case .notYetScanned:
                // TODO: implement delete button
                scanState.deleteButton.isHidden = true
                scanState.playbackButton.isHidden = true
                if scanState.isSelected {
                    scanState.progressLabel.text = Strings.READY_TO_SCAN
                } else {
                    scanState.progressLabel.text = Strings.NOT_YET_SCANNED
                }
            case .finishedScanning:
                // TODO: implement delete button
                //scanState.deleteButton.isHidden = false
                scanState.playbackButton.isHidden = false
                scanState.progressLabel.text = Strings.SCAN_COMPLETE
            
                if !bothScansComplete() {
                    // if only the contralateral was scanned, post the contralateral
                    // and make the suspected button selected
                    // TODO: allow toggling between the two states. Not
                    // implementing this now since it would need some server side
                    // updates to allow replacing audio files
                    if scanState.isSelected {
                        titleLabel.text = Strings.SUSPECTED_READY_TITLE
                        
                        postAudio(fileName: contralateralScanViewModel.fileName, herokuURL: Strings.CONTRALATERAL_HEROKU_URL)
                        switchSelectedState()
                    }
                }
                else {
                    titleLabel.text = Strings.READY_TO_CALCULATE_TITLE
                }
            }
        }
    }
    
    func switchSelectedState() {
        assert(!bothScansComplete())
        contralateralScanViewModel.isSelected = !contralateralScanViewModel.isSelected
        suspectedScanViewModel.isSelected = !suspectedScanViewModel.isSelected
        updateUI()
    }
    
    // MARK: Bluetooth
    func createNotificationForDataFromArduino() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "Notify"), object: nil , queue: nil) {
            notification in
            
            guard self.hasReceiviedInitialMessage else {
                // this is not a great way to do this but it works
                // not able to parse received messages yet, but they only
                // send once when bluetooth connects and then every time a button press
                // this guard makes sure we dont turn on the scanner for the initial
                // bluetooth connect message
                self.hasReceiviedInitialMessage = true
                return
            }
            
            if self.bothScansComplete() {
                print("both scans complete")
                self.titleLabel.text = "Calculating transmission rate"
                self.postToHeroku()
                return
            }
      
            if (self.contralateralScanViewModel.canStartQuickScan) {
                self.startScan(for: self.contralateralScanViewModel)
            }
            else if (self.suspectedScanViewModel.canStartQuickScan) {
                self.startScan(for: self.suspectedScanViewModel)
            }
        }
    }
    
    func bothScansComplete() -> Bool  {
        return ((self.contralateralScanViewModel.progress == .finishedScanning) &&
            (self.suspectedScanViewModel.progress == .finishedScanning))
    }
    
    func startScan(for viewModel: ScanViewModel) {
        /* update UI for scan in progress
         * start actuator, and start recording */
        
        let newAsciiText = NSMutableAttributedString(attributedString: self.consoleAsciiText!)
    
        viewModel.setScanProgress(to: .scanInProgress)
        updateUI()
        // todo: add setting for switching b/w sounds
        
        startRecording(fileName: viewModel.fileName)
        startSelectedSoundFile()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + recordingSeconds) {
            self.finishRecording()
            viewModel.setScanProgress(to: .finishedScanning)
            self.updateUI()
        }
    }
    
    // Write functions
    func writeValue(data: String){
        let valueString = (data as NSString).data(using: String.Encoding.utf8.rawValue)
        //change the "data" to valueString
        if let blePeripheral = blePeripheral{
            if let txCharacteristic = txCharacteristic {
                blePeripheral.writeValue(valueString!, for: txCharacteristic, type: CBCharacteristicWriteType.withResponse)
            }
        }
    }
    
    func writeCharacteristic(val: Int8){
        var val = val
        let ns = NSData(bytes: &val, length: MemoryLayout<Int8>.size)
        blePeripheral!.writeValue(ns as Data, for: txCharacteristic!, type: CBCharacteristicWriteType.withResponse)
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            return
        }
        print("Peripheral manager is running")
    }
    
    //Check when someone subscribe to our characteristic, start sending the data
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("Device subscribe to characteristic")
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print("\(error)")
            return
        }
    }
    
    // MARK: not Bluetooth
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func startRecording(fileName: String) {
        //1. create the session
        
        let url = getAudioFileUrl(name: fileName)
        print("start recording: " + url.absoluteString)
        let session = AVAudioSession.sharedInstance()
        
        do {
            // 2. configure the session for recording and playback
            // make sure this is okay
            try session.setCategory(AVAudioSession.Category(rawValue: convertFromAVAudioSessionCategory(AVAudioSession.Category.playAndRecord)), mode: .default)
            try session.setActive(true)
            // 3. set up a high-quality recording session
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            // 4. create the audio recording, and assign ourselves as the delegate
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            
            //5. Changing record icon to stop icon
            
        }
        catch let error {
            print("ERROR in startRecording")
            print(error)
            // failed to record!
        }
    }
    
    
    
    
    // MARK: audio methods
    
    
    // Stop recording
    func finishRecording() {
        audioRecorder?.stop()
        isRecording = false
        recordingExists = true
    }
    
    // Path for saving/retreiving the audio file
    func getAudioFileUrl(name: String) -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let docsDirect = paths[0]
        return docsDirect.appendingPathComponent(name + ".m4a")
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            finishRecording()
        } else {
            // Recording interrupted by other reasons like call coming, reached time limit.
        }
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            resetPlaybackButtonUI(button: contralateralScanViewModel.playbackButton)
            resetPlaybackButtonUI(button: suspectedScanViewModel.playbackButton)
        } else {
            print("audio player did not stop successfully")
            // Playing interrupted by other reasons like call coming, the sound has not finished playing.
        }
    }
    
    func postAudio(fileName: String, herokuURL: String) {
        print("posting audio for " + fileName)
        let url = getAudioFileUrl(name: fileName)
        Alamofire.upload(
            multipartFormData: { multipartFormData in
                multipartFormData.append(url, withName: fileName, fileName: fileName, mimeType: "audio/x-m4a")
                
        },
            to: herokuURL,
            encodingCompletion: { encodingResult in
                switch encodingResult {
                case .success(let upload, _, _):
                    upload.responseString { response in
                        print("img response")
                        print(response)
                        self.numAudioFilesPosted += 1
                        if (self.numAudioFilesPosted >= 2) {
                            self.getProcessedAudio()
                        }
                        
                    }
                case .failure(let encodingError):
                    print(encodingError)
                }
        }
        )
    }
    
    // get processed audio from server
    func getProcessedAudio() {
        guard let url = URL(string: "https://emilys-server.herokuapp.com/process_audio") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print(error as Any)
                return
            }
            DispatchQueue.main.async {
                do {
                    let jsonDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String : Any]
                    print(jsonDict)
                    let storyboard = UIStoryboard(name: "Main", bundle: nil)
                    var resultsViewController = storyboard.instantiateViewController(withIdentifier: "ResultsViewController") as! ResultsViewController
                    resultsViewController.jsonDict = jsonDict!
                    self.navigationController?.pushViewController(resultsViewController, animated: true)
                    
                } catch let error {
                    print(error)
                }
            }
        }
        task.resume()
    }

    private func startSelectedSoundFile() {
        let stringToSend = String(describing: trackIdSegControl.selectedSegmentIndex)
        writeValue(data: stringToSend)
    }
    
    func playSound(urlName: String){
        let url = getAudioFileUrl(name: urlName)
        
        do {
            // AVAudioPlayer setting up with the saved file URL
            let sound = try AVAudioPlayer(contentsOf: url)
            self.player = sound
            
            // Here conforming to AVAudioPlayerDelegate
            sound.delegate = self
            sound.prepareToPlay()
            sound.play()
        } catch {
            print("error loading file")
            // couldn't load file :(
        }
    }
    
    func postToHeroku() {
        assert(bothScansComplete())
        
        // post contralateral
        postAudio(fileName: suspectedScanViewModel.fileName, herokuURL: Strings.SUSPECTED_HEROKU_URL)
        
    }
    
    // MARK: playback buttons
    @IBAction func playContralateral(_ sender: UIButton) {
        togglePlaybackButtonUI(for: contralateralScanViewModel, button: sender)
    }
    
    @IBAction func playSuspected(_ sender: UIButton) {
        togglePlaybackButtonUI(for: suspectedScanViewModel, button: sender)
    }
    
    private func togglePlaybackButtonUI(for scanViewModel: ScanViewModel, button: UIButton) {
        if (button.titleLabel?.text?.elementsEqual(Strings.PLAY))! {
            button.setTitle(Strings.STOP, for: .normal)
            button.backgroundColor = Colors.CANCEL_BTN
            playSound(urlName: scanViewModel.fileName)
        }
        else {
            resetPlaybackButtonUI(button: button)
        }
    }
    
    private func resetPlaybackButtonUI(button: UIButton) {
        player?.stop()
         button.setTitle(Strings.PLAY, for: .normal)
        button.backgroundColor = Colors.PLAY_BUTTON
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromAVAudioSessionCategory(_ input: AVAudioSession.Category) -> String {
	return input.rawValue
}
