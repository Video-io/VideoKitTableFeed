//
//  ViewController.swift
//  VideoKitTableFeed
//
//  Created by Dennis Stücken on 11/11/20.
//
import UIKit
import VideoKitPlayer
import VideoKitCore

class ViewController: UITableViewController {
    var hasMoreVideos: Bool = true
    var currentPage: Int =  0
    var playlist = VKPlaylist(videos: [])
    var playersManager = VKPlayersManager(prerenderDistance: 3, preloadDistance: 10)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        
        // Setup delegates
        self.playersManager.delegate = self
        self.tableView.register(VideoCell.self, forCellReuseIdentifier: "VideoCell")
        
        // Wait until VideoKit's session is initialized, then set datasource and load videos
        NotificationCenter.default.addObserver(self, selector: #selector(self.sessionStateChanged(_:)), name: .VKAccountStateChanged, object: nil)
        sessionStateChanged()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadNextVideos()
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
    
    func loadNextVideos() {
        guard hasMoreVideos else { return }
        
        _ = VKVideoAPI.shared.videos(byTags: [], metadata: [:], page: currentPage, perPage: 10) { [weak self] (response, error) in
            if let error = error {
                print(error.localizedDescription)
                return
            }
            
            guard self != nil else { return }
            guard let response = response else { return }
            
            self?.insertNewRows(videos: response.videos)
            self?.currentPage = (self?.currentPage ?? 0) + 1
            
            if response.totalCount <= self?.playlist.count ?? 0 {
                self?.hasMoreVideos = false
            }
        }
    }
    
    func insertNewRows(videos: [VKVideo]) {
        guard videos.count > 0 else {
            return
        }
        
        DispatchQueue.main.async {
            self.playlist.addVideos(videos)
            self.playersManager.setPlaylist(self.playlist)
            self.tableView.reloadData()
        }
    }
}

extension ViewController: PlayerNodeDelegate {
    
    func requestPlayer(forVideo video: VKVideo, completion: @escaping VKPlayersManager.PlayerRequestCompletion) {
        playersManager.getPlayerFor(videoId: video.videoID, completion: completion)
    }
    
    func releasePlayer(forVideo video: VKVideo) {
        playersManager.releasePlayerFor(id: video.videoID)
    }
    
}

extension ViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return  1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playlist.count
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 220
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "VideoCell", for: indexPath) as! VideoCell
        cell.delegate = self
        cell.video = self.playlist.videoAt(indexPath.row)!
        return cell
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if tableView.indexPathsForVisibleRows?.contains(indexPath) ?? false {
            if let vNode = cell as? VideoCell {
                playersManager.setPlaylistIndex(indexPath.row)
                vNode.play()
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let vNode = cell as? VideoCell {
            playersManager.setPlaylistIndex(indexPath.row)
            vNode.pause()
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
