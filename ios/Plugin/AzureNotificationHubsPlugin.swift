import Foundation
import Capacitor
import UserNotifications
import WindowsAzureMessaging

enum PushNotificationError: Error {
    case tokenParsingFailed
    case tokenRegistrationFailed
}

@objc(AzureNotificationHubsPlugin)
public class AzureNotificationHubsPlugin: CAPPlugin {
    override public func load() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.didRegisterForRemoteNotificationsWithDeviceToken(notification:)),
                                               name: .capacitorDidRegisterForRemoteNotifications,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.didFailToRegisterForRemoteNotificationsWithError(notification:)),
                                               name: .capacitorDidFailToRegisterForRemoteNotifications,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /**
     * Register for push notifications
     */
    @objc func register(_ call: CAPPluginCall) {
        guard let notificationHubName = call.getString("notificationHubName") else {
            call.reject("Must provide notificationHubName")
            return
        }
        guard let connectionString = call.getString("connectionString") else {
            call.reject("Must provide connectionString")
            return
        }
        
        guard let tags = call.getString("tags") else {
            call.reject("Must provide tags, a comma separated string of tags")
            return
        }
        
        let options = MSNotificationHubOptions(withOptions: [.alert, .badge, .sound])!
        let tagsArray: [String] = tags.split(separator: ",").map { String($0)}
        DispatchQueue.main.async {
            MSNotificationHub.start(connectionString: connectionString, hubName: notificationHubName, options: options)
            MSNotificationHub.clearTags()
            MSNotificationHub.addTags(tagsArray)
        }
        call.resolve()
    }

    @objc func addTags(_ call: CAPPluginCall) {
        guard let tags: JSArray = call.getArray("tags") else {
            print("tags not sepcified")
            call.reject("Must provide an array of strings to use as tags")
            return
        }
        
        let tagsArray: [String] = tags.compactMap{ $0 as? String } //convert the jsArray into a [String]
        DispatchQueue.main.async {
            MSNotificationHub.addTags(tagsArray)
        }
        call.resolve()
    }
    
    @objc func clearTags(_ call: CAPPluginCall){
        DispatchQueue.main.async {
            MSNotificationHub.clearTags()
        }
        call.resolve()
    }
    
    @objc func clearAndAddTags(_ call: CAPPluginCall) {
        guard let tags: JSArray = call.getArray("tags") else {
            print("tags not sepcified")
            call.reject("Must provide an array of strings to use as tags")
            return
        }
        
        let tagsArray: [String] = tags.compactMap{ $0 as? String } //convert the jsArray into a [String]
        DispatchQueue.main.async {
            MSNotificationHub.clearTags()
            MSNotificationHub.addTags(tagsArray)
        }
        call.resolve()
    }
    

    @objc public func didRegisterForRemoteNotificationsWithDeviceToken(notification: NSNotification) {
        if let deviceToken = notification.object as? Data {
            let deviceTokenString = deviceToken.reduce("", {$0 + String(format: "%02X", $1)})
            notifyListeners("registration", data: [
                "value": deviceTokenString
            ])
        } else if let stringToken = notification.object as? String {
            notifyListeners("registration", data: [
                "value": stringToken
            ])
        } else {
            notifyListeners("registrationError", data: [
                "error": PushNotificationError.tokenParsingFailed.localizedDescription
            ])
        }
    }

    @objc public func didFailToRegisterForRemoteNotificationsWithError(notification: NSNotification) {
        guard let error = notification.object as? Error else {
            return
        }
        notifyListeners("registrationError", data: [
            "error": error.localizedDescription
        ])
    }
}
