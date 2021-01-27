//
//  VideoNode.swift
//  VideoKitTableFeed
//
//  Created by Dennis Stücken on 11/12/20.
//
import UIKit
import VideoKitCore
import VideoKitPlayer

class VideoCell: UITableViewCell {
    var delegate: PlayerNodeDelegate? {
        didSet {
            playerNode?.delegate = delegate
        }
    }
    
    var playerNode: PlayerNode?
    var video: VKVideo? {
        didSet {
            if let video = video {
                playerNode = PlayerNode(video: video)
                self.textLabel?.text = video.videoID
            }
        }
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func getThumbnailURL(video: VKVideo) -> URL? {
        return playerNode?.video.thumbnailImageURL
    }
    
    func isPlaying() -> Bool {
        return playerNode?.isPlaying() ?? false
    }
    
    func play() {
        playerNode?.play()
    }
    
    func pause() {
        playerNode?.pause()
    }
    
    @objc func overlayTapped() {
        self.playerNode?.togglePlayback()
    }
}
