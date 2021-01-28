//
//  ViewController.swift
//  VideoKitTableFeed
//
//  Created by Dennis Stücken on 11/11/20.
//
import UIKit
import VideoKitPlayer
import VideoKitCore
import VideoKitRecorder

class ViewController: UITableViewController {
    private var recorderVC = VKRecorderViewController()
    
    var playlist = VKPlaylist(videos: [])
    var playersManager = VKPlayersManager(prerenderDistance: 3, preloadDistance: 10)
    
    let cellMargin: CGFloat = 50
    let videoCellFrameHeight: CGFloat = 100
    
    var recordButton: UIButton = {
        let button = UIButton(frame: .zero)
        button.setTitle("Record", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .black
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        self.recorderVC.delegate = self
        self.recorderVC.dataSource = self
        
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(refresh), for: .valueChanged)
        
        self.playersManager.delegate = self
        self.tableView.register(PlayerTableViewCell.self, forCellReuseIdentifier: "PlayerTableViewCell")
        
        // Wait until VideoKit's session is initialized, then set datasource and load videos
        NotificationCenter.default.addObserver(self, selector: #selector(self.sessionStateChanged(_:)), name: .VKAccountStateChanged, object: nil)
        sessionStateChanged()
        
        tableView.addSubview(recordButton)
        recordButton.widthAnchor.constraint(equalToConstant: 200).isActive = true
        recordButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        NSLayoutConstraint.activate(
            [
                NSLayoutConstraint(item: recordButton, attribute: .centerX, relatedBy: .equal, toItem: tableView, attribute: .centerX, multiplier: 1.0, constant: 0.0),
                NSLayoutConstraint(item: recordButton, attribute: .centerY, relatedBy: .equal, toItem: tableView, attribute: .centerY, multiplier: 1.0, constant: 0.0)
            ]
        )
        
        recordButton.addAction(.init(handler: { (action) in
            self.present(self.recorderVC, animated: true, completion: nil)
        }), for: .touchUpInside)
        
        refresh()
        NotificationCenter.default.addObserver(self, selector: #selector(handleVideosCreated(_:)), name: .VKVideoCreated, object: nil)
    }
    
    /// This observer also receives uploaded videos from other devices
    @objc private func handleVideosCreated(_ notification: Notification) {
        if let object = notification.object as? [String : Any], let videoID = object["videoID"] as? String {
            print("Video with id \(videoID) uploaded.")
            VKVideoCache.shared.getVideo(videoID) { (video, error) in
                guard let video = video else { return }
                
                // Add received video if it does not exist
                self.insertVideoToTop(video: video)
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        //self.tableView.visibleCells.forEach({ ($0 as? VideoCell)?.pause() })
    }
}

extension ViewController {
    @objc func sessionStateChanged(_ notification: NSNotification? = nil) {
        DispatchQueue.main.async {
            if VKSession.current.state == .connected {
                self.tableView.delegate = self
                self.tableView.dataSource = self
            }
        }
    }
    
    @objc func refresh() {
        _ = VKVideoAPI.shared.videos(byTags: [], metadata: [:], page: 0, perPage: 10, sortOrder: "desc") { [weak self] (response, error) in
            guard let strongSelf = self else { return }
            
            if let error = error {
                print(error.localizedDescription)
                return
            }
            
            guard self != nil else { return }
            guard let response = response else { return }
            
            strongSelf.insertNewRows(videos: response.videos)
        }
    }
    
    func insertVideoToTop(video: VKVideo) {
        DispatchQueue.main.async {
            if !self.playlist.hasVideoById(video.videoID) {
                self.playlist.addVideo(video, at: 0)
                self.playersManager.setPlaylist(self.playlist)
                self.tableView.reloadData()
                self.refreshControl?.endRefreshing()
            }
        }
    }
    
    func insertNewRows(videos: [VKVideo]) {
        guard videos.count > 0 else {
            return
        }
        
        DispatchQueue.main.async {
            for video in videos {
                if !self.playlist.hasVideoById(video.videoID) {
                    self.playlist.addVideo(video)
                }
            }
            self.playersManager.setPlaylist(self.playlist)
            self.tableView.reloadData()
            self.refreshControl?.endRefreshing()
        }
    }
}

extension ViewController: VKRecorderViewControllerDataSource {
    func shouldEnableUploadWhileRecording() -> Bool {
        return true
    }
}

extension ViewController: VKRecorderViewControllerDelegate {
    func vkRecorderDidFinishUploadWhileRecording(_ video: VKVideo, _ session: VKRecorderSession) {
        print("Video uploaded")
        self.insertVideoToTop(video: video)
    }
    
    func didFailMergingClips(_ recorder: VKRecorder, error: Error, autoMerged: Bool) {
        print("Merging clips failed.")
    }
    
    func didFinishMergingClips(_ recorder: VKRecorder, mergedClipUrl: URL, autoMerged: Bool) {
        print("Clips merged: \(mergedClipUrl.absoluteString)")
    }
    
    func didTapNextButton(_ recorder: VKRecorder) {
        recorderVC.dismiss(animated: true, completion: nil)
    }
    
    func didExit(_ recorder: VKRecorder, recordingViewController: VKRecorderViewController) {
        // Finalize upload in case there was a video recorded
        recordingViewController.vkRecorder.finalizeUploadWhileRecording()
        
        recordingViewController.dismiss(animated: true, completion: nil)
        recorderVC.vkRecorder.endSession()
    }
}

extension ViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return  1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playlist.count
    }
    
    func getMinRatio() -> CGFloat {
        return tableView.frame.width / (tableView.frame.height - videoCellFrameHeight - 2 * cellMargin)
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let video = playlist.videoAt(indexPath.row) else { return 160 }
        let ratio = CGFloat.maximum(getMinRatio(), CGFloat(video.width) / CGFloat(video.height))
        
        return view.frame.width / ratio + cellMargin + videoCellFrameHeight
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PlayerTableViewCell", for: indexPath) as! PlayerTableViewCell
        let index = indexPath.row
        
        playersManager.getPlayerFor(index: index, completion: { (player, error) in
            guard let player = player else { return }
            
            cell.setPlayer(player: player)
            
            // Always play first row
            if indexPath.row == 0 {
                cell.play()
            }
        })
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if tableView.indexPathsForVisibleRows?.contains(indexPath) ?? false {
            if let vCell = cell as? PlayerTableViewCell {
                playersManager.setPlaylistIndex(indexPath.row)
                vCell.play()
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let video = playlist.videoAt(indexPath.row) else { return  }
        
        if let vCell = cell as? PlayerTableViewCell {
            vCell.pause()
        }
        
        playersManager.releasePlayerFor(id: video.videoID)
    }
}

extension ViewController: VKPlayersManagerProtocol {
    public func vkPlayersManagerNewPlayerCreated(_ manager: VKPlayersManager, _ player: VKPlayerViewController) {
        // Setup video player
        player.aspectMode = .resizeAspectFill
        player.showControls = false
        player.showSpinner = true
        player.showErrorMessages = false
        player.loop = true
    }
}
