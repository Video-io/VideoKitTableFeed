//
//  PlayerTableViewCell.swift
//  VideoKitTableFeed
//
//  Created by Dennis Stücken on 1/27/21.
//
import UIKit
import VideoKitCore
import VideoKitPlayer

class PlayerTableViewCell: UITableViewCell {
    var player: VKPlayerViewController?
    var shouldPlayOnPlayerSet: Bool = false
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.contentView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(togglePlayback)))
    }
    
    override func prepareForReuse() {
        player?.reset()
        self.contentView.subviews.forEach({ $0.removeFromSuperview() })
    }
    
    func setPlayer(player: VKPlayerViewController) {
        self.player = player

        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }

            player.view.removeFromSuperview()
            player.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            player.view.frame = self.contentView.frame
            self.contentView.addSubview(player.view)
            self.contentView.layoutIfNeeded()
            
            if self.shouldPlayOnPlayerSet {
                self.play()
            }
        }
    }
    
    
    func play() {
        shouldPlayOnPlayerSet = true
        player?.play()
    }
    
    func pause() {
        shouldPlayOnPlayerSet = false
        player?.pause()
    }
    
    @objc func togglePlayback() {
        player?.playState == .playing ? player?.pause() : player?.play()
    }
}
