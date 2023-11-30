//
//  AudioRecorder.swift
//  AIVoiceToTextOpenAI
//
//  Created by John goodstadt on 29/11/2023.
//

import Foundation
import AVFoundation

class AudioRecorder  {
	var avAudioRecorder: AVAudioRecorder = AVAudioRecorder()
	
	func setupAudioRecorder() {
		let audioFilename = getDocumentsDirectory().appendingPathComponent("recording.m4a")
		
		let settings = [
			AVFormatIDKey: Int(kAudioFormatMPEG4AAC), //deos not work on API
			AVSampleRateKey: 12000,
			AVNumberOfChannelsKey: 1,
			AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
		]

		do {
			self.avAudioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
			avAudioRecorder.prepareToRecord()
			print(avAudioRecorder.format)
		} catch {
			print("Failed to initialize the audio recorder: \(error)")
		}
	}

	func startRecording() {
		AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
			if granted {
				do {
					try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
					try AVAudioSession.sharedInstance().setActive(true)
					self!.avAudioRecorder.record()
					if ((self?.avAudioRecorder.isRecording) != nil) {
						if self?.avAudioRecorder == nil {
							print("audioRecorder? is nil")
						}
						print("audioRecorder?.isRecording")
					}
				}catch{
					print("Failed to set up the audio session: \(error)")
				}
			} else {
				print("Microphone permission was denied")
			}
		}
	}

	func stopRecording() {
		avAudioRecorder.stop()
	}

	private func getDocumentsDirectory() -> URL {
		FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
	}
}
