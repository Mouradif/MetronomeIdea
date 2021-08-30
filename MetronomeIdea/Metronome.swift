//
//  Metronome.swift
//  MetronomeIdea
//
//  Created by Alex Shubin on 26.03.17.
//  Copyright © 2017 Alex Shubin. All rights reserved.
//

import AVFoundation

class Metronome {
    
    private let audioPlayerNode: AVAudioPlayerNode
    private let audioFileMainClick: AVAudioFile
    private let audioFileAccentedClick: AVAudioFile
    private let audioEngine: AVAudioEngine
    
    init (mainClickFile: URL, accentedClickFile: URL? = nil) {
        
        audioFileMainClick = try! AVAudioFile(forReading: mainClickFile)
        audioFileAccentedClick = try! AVAudioFile(forReading: accentedClickFile ?? mainClickFile)
        
        audioPlayerNode = AVAudioPlayerNode()
        
        audioEngine = AVAudioEngine()
        audioEngine.attach(self.audioPlayerNode)
        
        audioEngine.connect(audioPlayerNode, to: audioEngine.mainMixerNode, format: audioFileMainClick.processingFormat)
        try! audioEngine.start()
    }
    
    private func generateBuffer(bpm: Double, beatsPerBar: UInt32, beatNote: UInt32) -> AVAudioPCMBuffer {
        
        audioFileMainClick.framePosition = 0
        audioFileAccentedClick.framePosition = 0
        
        let multiplier: Double = Double(4) / Double(beatNote)
        let beatLength = AVAudioFrameCount(audioFileMainClick.processingFormat.sampleRate * 60 * multiplier / bpm)
        let bufferMainClick = AVAudioPCMBuffer(pcmFormat: audioFileMainClick.processingFormat,
                                               frameCapacity: beatLength)!
        try! audioFileMainClick.read(into: bufferMainClick)
        bufferMainClick.frameLength = beatLength
        
        let bufferAccentedClick = AVAudioPCMBuffer(pcmFormat: audioFileMainClick.processingFormat,
                                                   frameCapacity: beatLength)!
        try! audioFileAccentedClick.read(into: bufferAccentedClick)
        bufferAccentedClick.frameLength = beatLength
        
        let bufferBar = AVAudioPCMBuffer(pcmFormat: audioFileMainClick.processingFormat,
                                         frameCapacity: beatLength * UInt32(beatsPerBar))!
        bufferBar.frameLength = beatLength * UInt32(beatsPerBar)
        
        // don't forget if we have two or more channels then we have to multiply memory pointee at channels count
        let channelCount = Int(audioFileMainClick.processingFormat.channelCount)
        let accentedClickArray = Array(
            UnsafeBufferPointer(start: bufferAccentedClick.floatChannelData![0],
                                count: channelCount * Int(beatLength))
        )
        let mainClickArray = Array(
            UnsafeBufferPointer(start: bufferMainClick.floatChannelData![0],
                                count: channelCount * Int(beatLength))
        )
        
        var barArray = [Float]()
        // one time for first beat
        barArray.append(contentsOf: accentedClickArray)
        // three times for regular clicks
        for _ in 1...(beatsPerBar - 1) {
            barArray.append(contentsOf: mainClickArray)
        }
        bufferBar.floatChannelData!.pointee.assign(from: barArray,
                                                   count: channelCount * Int(bufferBar.frameLength))
        return bufferBar
    }
    
    func play(bpm: Double, beatsPerBar: UInt32, beatNote: UInt32) {
        
        let buffer = generateBuffer(bpm: bpm, beatsPerBar: beatsPerBar, beatNote: beatNote)
        
        if audioPlayerNode.isPlaying {
            audioPlayerNode.scheduleBuffer(buffer, at: nil, options: .interruptsAtLoop, completionHandler: nil)
        } else {
            self.audioPlayerNode.play()
        }
        
        for i: UInt32 in 0...3 {
            self.audioPlayerNode.scheduleBuffer(buffer, at: AVAudioTime(sampleTime: AVAudioFramePosition(i * UInt32(buffer.frameLength)), atRate: audioFileMainClick.processingFormat.sampleRate), options: .interruptsAtLoop, completionHandler: nil)
        }
        
    }
    
    func stop() {
        audioPlayerNode.stop()
    }

    var isPlaying: Bool {
        return audioPlayerNode.isPlaying
    }
}
