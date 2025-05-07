//
//  AppDelegate.swift
//  ArZhaba
//
//  Created by Vladislav Ainshtein on 06.05.25.
//

import UIKit
import SwiftUI
import ARKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Set memory usage limits
        setMemoryUsageLimits()
        
        // Create the SwiftUI view that provides the window contents.
        let contentView = MainView()

        // Use a UIHostingController as window root view controller.
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIHostingController(rootView: contentView)
        self.window = window
        window.makeKeyAndVisible()
        
        return true
    }
    
    private func setMemoryUsageLimits() {
        // Limit memory usage by setting image cache capacity
        URLCache.shared.memoryCapacity = 5 * 1024 * 1024 // 5 MB
        URLCache.shared.diskCapacity = 20 * 1024 * 1024 // 20 MB
        
        // Register for memory warning notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc func handleMemoryWarning() {
        // Release memory when receiving memory warning
        URLCache.shared.removeAllCachedResponses()
        
        // Force a garbage collection cycle (this doesn't directly trigger GC, but helps)
        autoreleasepool {
            // Empty autorelease pool to help with memory pressure
        }
        
        // Log memory warning
        print("Memory warning received - clearing caches")
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Pause AR sessions when app resigns active state
        ARAnchorService.shared.returnToIdle()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Clear caches when moving to background
        URLCache.shared.removeAllCachedResponses()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        // Don't automatically restart scanning, let the user decide when to start
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Clean up resources before termination
        NotificationCenter.default.removeObserver(self)
    }
}

