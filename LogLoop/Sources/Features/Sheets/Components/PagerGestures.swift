import SwiftUI
import UIKit

/// Da iOS 26 si torna indietro con uno swipe verso destra da qualunque punto dello schermo, e
/// qui ruberebbe lo swipe tra i giorni: resta attivo solo quello dal bordo sinistro.
struct ContentPopGestureDisabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            setContentPopEnabled(false)
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            setContentPopEnabled(true)
        }

        private func setContentPopEnabled(_ isEnabled: Bool) {
            if #available(iOS 26, *) {
                navigationController?.interactiveContentPopGestureRecognizer?.isEnabled = isEnabled
            }
        }
    }
}

/// Sulle righe delle attività lo swipe verso sinistra deve mostrare "Elimina" invece di
/// cambiare pagina: lo scorrimento delle pagine aspetta che lo swipe della riga rinunci.
/// Fuori dalle righe, o verso destra, lo swipe della riga non parte e le pagine scorrono.
struct RowSwipePriority: UIViewRepresentable {
    func makeUIView(context: Context) -> HookView { HookView() }
    func updateUIView(_ view: HookView, context: Context) { view.connect() }

    final class HookView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            connect()
        }

        func connect() {
            // A vista montata, così la lista della pagina esiste già.
            DispatchQueue.main.async { [weak self] in
                guard let self, window != nil, let pager = pagingScrollView() else { return }
                for list in pager.descendants(of: UICollectionView.self) {
                    for recognizer in list.gestureRecognizers ?? []
                    where String(describing: type(of: recognizer)).contains("SwipeAction") {
                        pager.panGestureRecognizer.require(toFail: recognizer)
                    }
                }
            }
        }

        /// Lo scorrimento orizzontale delle pagine che contiene questa vista.
        private func pagingScrollView() -> UIScrollView? {
            var view = superview
            while let current = view {
                if let scrollView = current as? UIScrollView, !(scrollView is UICollectionView),
                   scrollView.contentSize.width > scrollView.bounds.width {
                    return scrollView
                }
                view = current.superview
            }
            return nil
        }
    }
}

private extension UIView {
    func descendants<T: UIView>(of type: T.Type) -> [T] {
        subviews.flatMap { subview in
            (subview as? T).map { [$0] } ?? subview.descendants(of: type)
        }
    }
}
