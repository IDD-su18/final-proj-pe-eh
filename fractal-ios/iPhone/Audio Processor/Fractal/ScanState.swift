//
//  ScanViewModel.swift
//  Audio Processor
//
//  Created by Paige Plander on 8/9/18.
//  Copyright © 2018 Matthew Jeng. All rights reserved.
//

import Foundation
import UIKit


enum ScanLocation: String {
    case Contralateral
    case Suspected
}

enum ScanProgress {
    case scanInProgress
    case scanCancelled
    case notYetScanned
    case finishedScanning
}

class ScanViewModel {
    let location: ScanLocation
    var progress: ScanProgress = .notYetScanned
    var isSelected: Bool
    
    var canStartQuickScan: Bool {
        return isSelected && (progress == .notYetScanned) || (progress == .scanCancelled)
    }

    // UI stuff
    let progressLabel: UILabel
    let selectButton: UIButton
    let deleteButton: UIButton
    let playbackButton: UIButton
    let bgView: UIView
    
    func setScanProgress(to newProgress: ScanProgress) {
        self.progress = newProgress
    }
    
    init(progressLabel: UILabel, playbackButton: UIButton, bgView: UIView, deleteButton: UIButton, selectButton: UIButton) {
        // tODO finish initizing
        
        
        // UI elements
        self.progressLabel = progressLabel
        self.playbackButton = playbackButton
        self.bgView = bgView
        self.deleteButton = deleteButton
        self.selectButton = selectButton
    }
    
}
