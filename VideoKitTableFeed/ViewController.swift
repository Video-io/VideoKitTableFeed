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
    
    var playlist = VKPlaylist()
    var playersManager = VKPlayersManager(prerenderDistance: 3, preloadDistance: 10)
    
    var isFetching: Bool = true
    let cellMargin: CGFloat = 20
    
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
        self.tableView.estimatedRowHeight = tableView.frame.width * 9 / 16
        self.tableView.separatorStyle = .none
        
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(refresh), for: .valueChanged)

        // Set recorder delegates
        self.recorderVC.delegate = self
        self.recorderVC.dataSource = self
        
        // Set players manager delegate
        self.playersManager.delegate = self
        self.tableView.register(PlayerTableViewCell.self, forCellReuseIdentifier: "PlayerTableViewCell")
        
        // Wait until VideoKit's session is initialized, then set datasource and load videos
        NotificationCenter.default.addObserver(self, selector: #selector(self.sessionStateChanged(_:)), name: .VKAccountStateChanged, object: nil)
        sessionStateChanged()
        
        // Subscribe on new videos
        NotificationCenter.default.addObserver(self, selector: #selector(handleVideosCreated(_:)), name: .VKVideoCreated, object: nil)
        
        tableView.addSubview(recordButton)
        recordButton.widthAnchor.constraint(equalToConstant: 200).isActive = true
        recordButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        recordButton.centerXAnchor.constraint(equalTo: tableView.centerXAnchor).isActive = true
        recordButton.centerYAnchor.constraint(equalTo: tableView.centerYAnchor).isActive = true
        recordButton.addAction(.init(handler: { (action) in
            self.present(self.recorderVC, animated: true, completion: nil)
        }), for: .touchUpInside)
        
        refresh()
    }
    
    /// This observer also receives uploaded videos from other devices
    @objc private func handleVideosCreated(_ notification: Notification) {
        if let userInfo = notification.userInfo as? [String : Any],
           let video = userInfo["video"] as? VKVideo {
            // Add received video if it does not exist
            self.insertVideoToTop(video: video)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        scrollViewDidScroll(tableView)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        pausePlayers()
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
        // Initialize playlist with all videos from the app in descending order
        // and set it to players manager
        self.playlist = VKFilteredPlaylist(withFilter: VKVideoFilter(), sortOrder: .desc)
        self.playlist.delegate = self
        self.playersManager.setPlaylist(self.playlist)
        self.tableView.reloadData()
        self.refreshControl?.endRefreshing()
    }
    
    func insertVideoToTop(video: VKVideo) {
        DispatchQueue.main.async {
            if !self.playlist.hasVideoById(video.videoID) {
                self.playlist.addVideo(video, at: 0)
                self.playersManager.setPlaylist(self.playlist, index: 0)
                self.tableView.scrollToRow(
                    at: IndexPath(row: 0, section: 0),
                    at: UITableView.ScrollPosition.top,
                    animated: true
                )
                self.tableView.reloadData()
                self.pausePlayers()
            }
        }
    }
    
    func pausePlayers() {
        tableView.visibleCells.forEach({ ($0 as? PlayerTableViewCell)?.pause() })
    }
}

extension ViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playlist.count
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let video = playlist.videoAt(indexPath.row) else { return 160 }
        let videoRatio = video.width > 0 ? CGFloat(video.width) / CGFloat(video.height) : 9 / 16
        let minRatio = tableView.frame.width / (tableView.frame.height - 2 * cellMargin)
        let ratio = CGFloat.maximum(minRatio, videoRatio)

        return max(320, view.frame.width / ratio + cellMargin)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PlayerTableViewCell", for: indexPath) as! PlayerTableViewCell
        
        // Request prepared video player for new cell
        playersManager.getPlayerFor(index: indexPath.row, completion: { (player, error) in
            guard let player = player else { return }
            
            DispatchQueue.main.async { [weak self] in
                // Request cell by indexPath to make sure it's still visible
                guard let cell = tableView.cellForRow(at: indexPath) as? PlayerTableViewCell else { return }
                
                cell.setPlayer(player: player)
                
                // Trigger scroll handler for first cell, to start play it.
                if indexPath.row == 0 {
                    self?.scrollViewDidScroll(tableView)
                }
            }
        })
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let video = playlist.videoAt(indexPath.row) else { return }
        
        // Release player for cells which is not visible anymore
        playersManager.releasePlayerFor(id: video.videoID)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) as? PlayerTableViewCell else { return }

        cell.togglePlayback()
        cell.selectionStyle = .none
    }
}

extension ViewController {
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if tableView == scrollView {
            let yOffset = tableView.contentOffset.y
            let width = tableView.bounds.size.width
            let height = tableView.bounds.size.height
            let y = tableView.contentOffset.y == 0 ? 0 : yOffset + height / 4

            // Looking for cells in the middle of the screen
            if tableView.indexPathsForRows(in: CGRect(x: 0, y: y, width: width, height: height / 2))?.first(where: { path in
                guard let cell = tableView.cellForRow(at: path) as? PlayerTableViewCell else { return false }
                guard playlist.videoAt(path.row) != nil else { return false }
                
                // Set current video index to players manager. It's important to update players
                // manager with actual video index, so it can preload and prepare closed videos properly.
                playersManager.setPlaylistIndex(path.row)
                
                // If we have only 5 more videos in the playlist load next bunch of videos.
                if let filteredPlaylist = playlist as? VKFilteredPlaylist, (
                    !isFetching &&
                    path.row + 5 > filteredPlaylist.count &&
                    filteredPlaylist.count != filteredPlaylist.totalCount
                ) {
                    isFetching = true
                    filteredPlaylist.loadNextVideos()
                }
                
                // Pause all videos and play current video
                if cell.player?.playState != .playing && viewIfLoaded?.window != nil {
                    pausePlayers()
                    cell.play()
                }

                return true
            }) == nil {
                pausePlayers()
            }
        }
    }
}

extension ViewController: VKPlaylistDelegate {
    func loaded(videos: [VKVideo]) {
        isFetching = false
        
        // Playlist loaded more videos, update table view
        DispatchQueue.main.async { [weak self] in
            self?.tableView.reloadData()
        }
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
