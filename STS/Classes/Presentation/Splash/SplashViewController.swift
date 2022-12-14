//
//  SplashViewController.swift
//  Nursing
//
//  Created by Andrey Chernyshev on 17.01.2021.
//

import UIKit
import RxSwift
import RxCocoa
import OtterScaleiOS

final class SplashViewController: UIViewController {
    lazy var mainView = SplashView()
    
    private lazy var disposeBag = DisposeBag()
    
    private lazy var viewModel = SplashViewModel()
    
    private lazy var sdkInitialize = SplashSDKInitialize()
    private lazy var onboardingNavigate = SplashOnboardingNavigate(vc: self, viewModel: viewModel)
    
    override func loadView() {
        view = mainView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sdkInitialize.initialize { [weak self] progress in
            guard let self = self else {
                return
            }
            
            switch progress {
            case .error:
                self.activity(state: .none)
            case .initializing:
                self.activity(state: .sdkInitialize)
            case .complete:
                self.activity(state: .library)
                self.viewModel.validationComplete.accept(Void())
            }
        }
        
        viewModel.step()
            .drive(onNext: { [weak self] step in
                guard let self = self else {
                    return
                }
                
                self.activity(state: step == .onboarding ? .prepareOnboarding : .none)
                self.step(step)
            })
            .disposed(by: disposeBag)
        
        viewModel.tryAgain = { [weak self] error -> Observable<Void> in
            guard let self = self else {
                return .never()
            }
            
            return self.openError()
        }
    }
}

// MARK: Make
extension SplashViewController {
    static func make() -> SplashViewController {
        SplashViewController()
    }
}

// MARK: PaygateViewControllerDelegate
extension SplashViewController: PaygateViewControllerDelegate {
    func paygateDidClosed(with result: PaygateViewControllerResult) {
        step(.course)
    }
}

// MARK: CoursesViewControllerDelegate
extension SplashViewController: CoursesViewControllerDelegate {
    func coursesViewControllerDismissed() {
        viewModel.courseSelected.accept(Void())
    }
}

// MARK: Private
private extension SplashViewController {
    func step(_ step: SplashViewModel.Step) {
        switch step {
        case .onboarding:
            onboardingNavigate.navigate { [weak self] progress in
                guard let self = self else {
                    return
                }
                
                switch progress {
                case .error:
                    self.activity(state: .none)
                case .downloading:
                    self.activity(state: .prepareOnboarding)
                case .complete:
                    UIApplication.shared.windows.filter {$0.isKeyWindow}.first?.rootViewController = OnboardingViewController.make()
                }
            }
        case .course:
            UIApplication.shared.windows.filter {$0.isKeyWindow}.first?.rootViewController = CourseViewController.make()
        case .paygate:
            let vc = PaygateViewController.make()
            vc.delegate = self
            present(vc, animated: true)
        case .courses:
            let vc = CoursesViewController.make()
            vc.delegate = self
            present(vc, animated: true)
        }
    }
    
    func activity(state: SplashActivity) {
        state == .none ? mainView.preloaderView.stopAnimating() : mainView.preloaderView.startAnimating()
        
        let attrs = TextAttributes()
            .textColor(Appearance.greyColor)
            .font(Fonts.SFProRounded.regular(size: 17.scale))
            .lineHeight(23.8.scale)
            .textAlignment(.center)
        mainView.preloaderLabel.attributedText = state.text.attributed(with: attrs)
    }
    
    func openError() -> Observable<Void> {
        Observable<Void>
            .create { [weak self] observe in
                guard let self = self else {
                    return Disposables.create()
                }
                
                let vc = TryAgainViewController.make {
                    observe.onNext(())
                }
                self.present(vc, animated: true)
                
                return Disposables.create()
            }
    }
}
