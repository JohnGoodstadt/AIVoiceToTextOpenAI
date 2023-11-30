//
//  ContentView.swift
//  AIVoiceToTextOpenAI
//
//  Created by John goodstadt on 28/11/2023.
//

import SwiftUI
import AVFoundation

let M4Afilename = "recording.m4a"
let apiKey = "Your API Key Here"
let urlString = "https://api.openai.com/v1/audio/translations"

struct ContentView: View {
	
	@State private var transscribedText = "Spoken text will appear here"
	@State private var textColor = Color.blue
	@State var hideActivityIndicator: Bool = true
	
	private var audioRecorder: AudioRecorder = AudioRecorder()
	
	var body: some View {
		VStack {
			
			Text(transscribedText)
				.foregroundColor(textColor)
				.padding()
				.padding([.bottom,.top],40)
			
			Text("Press to translate mp3 from bundle")
				.padding()
				.padding(.bottom,20)
			
			Button(action: {
				hideActivityIndicator = false
				callOpenAI() { result in
					hideActivityIndicator = true
					switch result {
						case .success(let text):
							transscribedText = text
						case .failure(let error):
							transscribedText = error.localizedDescription
					}
					textColor = Color.red
				}
			}) {
				ZStack {
					Image(systemName: "play.fill")
						.frame(height: 60)
						.imageScale(.large)
						.foregroundColor(.accentColor)
						.font(.system(size: 60))
						.padding()
				}
			}
			
			Divider().frame(height: 1)
				.overlay(.gray)
				.padding()
			
			Text("Press and speak")
				.padding()
				.padding(.bottom,20)
			
			Button(action: {
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { //need more time to capture last word (1/2 a second)
					hideActivityIndicator = false
					audioRecorder.stopRecording() //writes file
					
					let finalAudio = readLocallyCachedAudio(M4Afilename)
					
					if finalAudio.count > 1000 {
						callOpenAI(dataInBuffer: finalAudio) { result in
							hideActivityIndicator = true
							switch result {
								case .success(let text):
									transscribedText = text
								case .failure(let error):
									transscribedText = error.localizedDescription
							}
						}
					}else{
						hideActivityIndicator = true
						print("microphone m4p is not large enough: \(finalAudio.count)")
						transscribedText = "Problem recording track. Please try again"
					}
					textColor = Color.red
				}
				
			}) {
				ZStack {
					Image(systemName: "mic")
						.frame(height: 60)
						.imageScale(.large)
						.foregroundColor(.accentColor)
						.font(.system(size: 60))
						.padding()
				}
			}
			.simultaneousGesture(
				LongPressGesture(minimumDuration: 0.1).onEnded({_ in
					print("startRecording")
					audioRecorder.startRecording()
				})
			)
			Spacer()
			ActivityIndicatorView(tintColor: .red, scaleSize: 2.0)
				.padding([.bottom,.top],16)
				.hidden(hideActivityIndicator)
		}.onAppear {
			audioRecorder.setupAudioRecorder()
		} //: VSTACK
		
		
	}
	
	
	func callOpenAI(dataInBuffer:Data = Data(),completion: @escaping ((Result<String, Error>)) -> Void) {
		

		let bundledMP3 = "JA64-thank you"
		
		// The URL of the API endpoint
		let url = URL(string: urlString)!
		
		// Prepare the URLRequest
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
		
		// Define the MIME type boundary (this can be any unique string)
		let boundary = "Boundary-\(UUID().uuidString)"
		
		// Set the content type
		request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
		
		// Create the body
		let httpBody = NSMutableData()
		
		// Add the model parameter
		let modelParameter = "whisper-1"  // Replace with the actual model name
		httpBody.append("--\(boundary)\r\n".data(using: .utf8)!)
		httpBody.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
		httpBody.append("\(modelParameter)\r\n".data(using: .utf8)!)
		
		// Add the file
		let fieldName = "file"
		let fileName = "yourfile.m4a"
		
		
		if dataInBuffer.isEmpty {
			let importURL = URL(fileURLWithPath: Bundle.main.path(forResource: bundledMP3, ofType: "mp3")!)
			if let fileData = try? Data(contentsOf:importURL) {
				httpBody.append("--\(boundary)\r\n".data(using: .utf8)!)
				httpBody.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
				httpBody.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
				httpBody.append(fileData)
				httpBody.append("\r\n".data(using: .utf8)!)
			}
		}else{
			httpBody.append("--\(boundary)\r\n".data(using: .utf8)!)
			httpBody.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
			httpBody.append("Content-Type: audio/mpeg\r\n\r\n".data(using: .utf8)!)
			httpBody.append(dataInBuffer)
			httpBody.append("\r\n".data(using: .utf8)!)
			
		}
		
		
		
		// End of the body
		httpBody.append("--\(boundary)--\r\n".data(using: .utf8)!)
		
		// Set the body of the request
		request.httpBody = httpBody as Data
		
		// Perform the request
		let session = URLSession.shared
		let task = session.dataTask(with: request) { data, response, error in
			if let error = error {
				print("Error: \(error)")
				completion(.failure(error))
				return
			}
			
			if let response = response as? HTTPURLResponse {
				print("Response Status Code: \(response.statusCode)")
				if response.statusCode != 200 {
					//					let e = Error("Response code not 200")
					completion(.success("Response code not 200"))
				}
			}
			
			if let data = data, let dataString = String(data: data, encoding: .utf8) {
				print("Response Data: \(dataString)")
				
				if let dict = dataString.convertToDictionary() {
					if let text = dict["text"] as? String {
						completion(.success(text))
					}
					
				}
				
			}
		}
		
		task.resume()
		
	}
	func convertToDictionary(text: String) -> [String: Any]? {
		if let data = text.data(using: .utf8) {
			do {
				return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
			} catch {
				print(error.localizedDescription)
			}
		}
		return nil
	}
	func setupAudioRecorder() {
		audioRecorder.setupAudioRecorder()
	}
	
	func startRecording() {
		audioRecorder.startRecording()
	}
	
	func stopRecording() {
		audioRecorder.stopRecording()
	}
	
	private func getDocumentsDirectory() -> URL {
		FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
	}
	func readLocallyCachedAudio(_ filename: String) -> Data {
		
		do{
			print(getDocumentsDirectory().appendingPathComponent(filename))
			return try Data(contentsOf: getDocumentsDirectory().appendingPathComponent(filename))
		}catch{
			print(error)
		}
		
		
		return Data()
		
	}
	struct ActivityIndicatorView: View {
		var tintColor: Color = .blue
		var scaleSize: CGFloat = 1.0
		
		var body: some View {
			ProgressView()
				.scaleEffect(scaleSize, anchor: .center)
				.progressViewStyle(CircularProgressViewStyle(tint: tintColor))
		}
	}
}
fileprivate extension View {
	@ViewBuilder func hidden(_ shouldHide: Bool) -> some View {
		switch shouldHide {
			case true: self.hidden()
			case false: self
		}
	}
}
extension String {
	func convertToDictionary() -> Dictionary<String, Any>? {
		if let data = self.data(using: .utf8) {
			do {
				return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
			} catch {
				print(error.localizedDescription)
			}
		}
		return nil
	}
}

#Preview {
	ContentView()
}
