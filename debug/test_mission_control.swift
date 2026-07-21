import Cocoa

class Observer {
    @objc func handle(_ note: Notification) {
        print("Notification: \(note.name.rawValue)")
    }
}

let obs = Observer()
DistributedNotificationCenter.default().addObserver(obs, selector: #selector(Observer.handle(_:)), name: nil, object: nil)

print("Listening for 10 seconds. Press F3 (Mission Control) now!")
RunLoop.current.run(until: Date().addingTimeInterval(10))
print("Done.")
