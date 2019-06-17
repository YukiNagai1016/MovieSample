//
//  ViewController.swift
//  MovieSample
//
//  Created by 優樹永井 on 2019/06/17.
//  Copyright © 2019 com.nagai. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

class ViewController: UIViewController , AVCaptureFileOutputRecordingDelegate {
    
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var footerView: UIView!
    @IBOutlet weak var startStopButton: UIButton!
    
    var isRecoding = false
    // セッションのインスタンス生成
    let captureSession = AVCaptureSession()
    /// ビデオデバイス
    var videoDevice: AVCaptureDevice!
    /// オーディオデバイス
    var audioDevice: AVCaptureDevice!
    /// ファイル出力
    var fileOutput: AVCaptureMovieFileOutput!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        // 入力（背面カメラ）
        videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        let videoInput = try! AVCaptureDeviceInput.init(device: videoDevice)
        captureSession.addInput(videoInput)
        // 入力（マイク）
        audioDevice = AVCaptureDevice.default(for: .audio)
        let audioInput = try! AVCaptureDeviceInput.init(device: audioDevice)
        captureSession.addInput(audioInput);
        // 出力（動画ファイル）
        fileOutput = AVCaptureMovieFileOutput()
        captureSession.addOutput(fileOutput)
        // プレビュー
        let videoLayer = AVCaptureVideoPreviewLayer.init(session: captureSession)
        videoLayer.frame = previewView.bounds
        videoLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewView.layer.addSublayer(videoLayer)
        // セッションの開始
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
        screenInitialization()
    }
    
    // 録画の開始・停止ボタン
    @IBAction func tapStartStopButton(_ sender: Any) {
        
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentsDirectory = paths[0] as String
        let filePath : String? = "\(documentsDirectory)/temp.mp4"
        let fileURL : NSURL = NSURL(fileURLWithPath: filePath!)
        if isRecoding { // 録画終了
            fileOutput?.stopRecording()
        } else { // 録画開始
            fileOutput?.startRecording(to: fileURL as URL, recordingDelegate: self)
        }
        
        // ライブラリへの保存
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL as URL)
        }) { completed, error in
            if completed {
                print("Video is saved!")
            }
        }
        isRecoding = !isRecoding
        screenInitialization()
    }
    
    // 録画完了
    public func capture(_ captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
        // ライブラリへの保存
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
        }) { completed, error in
            if completed {
                print("Video is saved!")
            }
        }
    }
    
    func screenInitialization(){
        startStopButton.setImage(UIImage(named: isRecoding ? "startButton" : "stopButton"), for: .normal)
        headerView.alpha = isRecoding ? 0.6 : 1.0
        footerView.alpha = isRecoding ? 0.6 : 1.0
    }
    
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        print("録画完了")
        
    }
    
    private func switchFormat(desiredFps: Double) {
        let isRunning = captureSession.isRunning
        if isRunning { captureSession.stopRunning() }  // セッションが始動中なら一時的に停止しておく
        
        // 取得したフォーマットを格納する変数
        var selectedFormat: AVCaptureDevice.Format! = nil
        // そのフレームレートの中で一番大きい解像度を取得する
        var currentMaxWidth: Int32 = 0
        
        // フォーマットを探る
        for format in videoDevice.formats {
            // フォーマット内の情報を抜き出す (for in と書いているが1つの format につき1つの range しかない)
            for range: AVFrameRateRange in format.videoSupportedFrameRateRanges {
                let description = format.formatDescription as CMFormatDescription  // フォーマットの説明
                let dimensions = CMVideoFormatDescriptionGetDimensions(description)  // 幅・高さ情報を抜き出す
                let width = dimensions.width  // 幅
                
                // 指定のフレームレートで一番大きな解像度を得る (1920px 以上は選ばない)
                if desiredFps == range.maxFrameRate && currentMaxWidth <= width && width <= 1920 {
                    selectedFormat = format
                    currentMaxWidth = width
                }
            }
        }
        
        // フォーマットが取得できていれば設定する
        if selectedFormat != nil {
            do {
                try videoDevice.lockForConfiguration()  // ロックできなければ例外を投げる
                videoDevice.activeFormat = selectedFormat
                videoDevice.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(desiredFps))  // Swift 4.2.1 になって
                videoDevice.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(desiredFps))  // value と timescale の引数名を書かないといけなくなった
                videoDevice.unlockForConfiguration()
                if isRunning { captureSession.startRunning() }  // セッションが始動中だった場合は一時停止していたものを再開する
            }
            catch {
                print("フォーマット・フレームレートが指定できなかった : \(desiredFps) fps")
            }
        }
        else {
            print("フォーマットが取得できなかった : \(desiredFps) fps")
        }
    }
    
//    public func capture(_ captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
//        // ライブラリへの保存
//        PHPhotoLibrary.shared().performChanges({
//            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
//        }) { completed, error in
//            if completed {
//                print("Video is saved!")
//            }
//        }
//    }
    
    
}
