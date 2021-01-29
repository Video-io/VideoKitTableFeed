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
    
    var playerView = UIView()
    var playIcon: UIImageView = {
        let view = UIImageView(image: UIImage(systemName: "play.fill"))
        view.contentMode = .scaleToFill
        view.tintColor = .white
        return view
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        addSubview(playerView)
        playerView.clipsToBounds = true
        playerView.translatesAutoresizingMaskIntoConstraints = false
        playerView.topAnchor.constraint(equalTo: topAnchor, constant: 10).isActive = true
        playerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10).isActive = true
        playerView.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        playerView.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
        
        addSubview(playIcon)
        playIcon.translatesAutoresizingMaskIntoConstraints = false
        playIcon.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        playIcon.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        playIcon.isHidden = true
        
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        self.shouldPlayOnPlayerSet = false
        self.playerView.subviews.forEach({ $0.removeFromSuperview() })
    }
    
    func setPlayer(player: VKPlayerViewController) {
        self.player = player

        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }
            
            player.view.removeFromSuperview()
            player.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            player.view.frame = self.playerView.frame
            self.playerView.addSubview(player.view)
            self.contentView.layoutIfNeeded()
            self.playIcon.isHidden = true
            
            if self.shouldPlayOnPlayerSet {
                self.play()
            }
        }
    }
    
    func play() {
        shouldPlayOnPlayerSet = true
        player?.play()
        self.playIcon.isHidden = true
    }
    
    func pause() {
        shouldPlayOnPlayerSet = false
        player?.pause()
    }
    
    @objc func togglePlayback() {
        let isPlaying = player?.playState == .playing

        playIcon.isHidden = !isPlaying
        isPlaying ? pause() : play()
    }
}
