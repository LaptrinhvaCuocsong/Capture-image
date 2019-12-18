//
//  HomeVC.swift
//  CapturePhoto
//
//  Created by Apple on 12/14/19.
//  Copyright © 2019 Apple. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class HomeVC: UIViewController {

    @IBOutlet weak var backgroundView: UIImageView!
    @IBOutlet weak var btnChooseImage: UIButton!
    
    private let bag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        btnChooseImage.layer.cornerRadius = 10.0
        
        btnChooseImage.rx.tap
            .debounce(.milliseconds(200), scheduler: MainScheduler.instance)
            .asObservable()
            .subscribe(onNext: {[weak self] (_) in
                self?.pushToPhotoVC()
            })
            .disposed(by: bag)
    }
    
    private func pushToPhotoVC() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let photoVC = storyboard.instantiateViewController(identifier: "PhotoVC") as! PhotoVC
        photoVC.delegate = self
        navigationController?.pushViewController(photoVC, animated: true)
    }
    
}

extension HomeVC: PhotoVCDelegate {
    
    func didChooseImage(_ image: UIImage) {
        navigationController?.popToViewController(self, animated: true)
        navigationController?.navigationBar.isHidden = true
        backgroundView.image = image
    }
    
}
