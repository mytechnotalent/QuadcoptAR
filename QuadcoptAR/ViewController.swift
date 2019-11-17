//
//  ViewController.swift
//  QuadcoptAR
//
//  Created by Kevin Thomas on 12/30/18.
//  Copyright © 2018 Kevin Thomas. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, SCNPhysicsContactDelegate {
    
    /////////////////////
    // MARK: - VARIABLES
    ////////////////////
    
    // Used to instantiate sceneView
    @IBOutlet var sceneView: ARSCNView!
    
    // Used to display timer to player
    @IBOutlet weak var timerLabel: UILabel!
    
    // Used to display score to player
    @IBOutlet weak var scoreLabel: UILabel!
    
    // Used to store the score
    var score = 0
    
    ///////////////////
    // MARK: - BUTTONS
    //////////////////
    
    // Bullet button
    @IBAction func onBulletButton(_ sender: Any) {
        fireMissile(type: "bullet")
    }
    
    /////////////////
    // MARK: - MATHS
    ////////////////
    
    // (direction, position)
    func getUserVector() -> (SCNVector3, SCNVector3) {
        if let frame = self.sceneView.session.currentFrame {
            // 4x4 transform matrix describing camera in world space
            let mat = SCNMatrix4(frame.camera.transform)
            // Orientation of camera in world space
            let dir = SCNVector3(-1 * mat.m31, -1 * mat.m32, -1 * mat.m33)
            // Location of camera in world space
            let pos = SCNVector3(mat.m41, mat.m42, mat.m43)
            
            return (dir, pos)
        }
        
        return (SCNVector3(0, 0, -1), SCNVector3(0, 0, -0.2))
    }
    
    //////////////////////////
    // MARK: - VIEW FUNCTIONS
    /////////////////////////
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = false 
        
        // Create default lighting
        self.sceneView.autoenablesDefaultLighting = true
        
        // Set the physics delegate
        sceneView.scene.physicsWorld.contactDelegate = self
        
        // Update the labels cornerRadius at runtime
        timerLabel.layer.masksToBounds = true
        timerLabel.layer.cornerRadius = 30
        scoreLabel.layer.masksToBounds = true
        scoreLabel.layer.cornerRadius = 30
        
        // Add objects to shoot at
        addTargetNodes()
        
        // Play background music
        playBackgroundMusic()
        
        // Start timer
        runTimer()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Create environmental lighting
        configuration.environmentTexturing = .automatic
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    /////////////////
    // MARK: - TIMER
    ////////////////
    
    // To store how many sceonds the game is played for
    var seconds = 30
    
    // Timer
    var timer = Timer()
    
    // To keep track of whether the timer is on
    var isTimerRunning = false
    
    // To run the timer
    func runTimer() {
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: (#selector(self.updateTimer)), userInfo: nil, repeats: true)
    }
    
    // Decrements seconds by 1, updates the timerLabel and calls gameOver if seconds is 0
    @objc func updateTimer() {
        if seconds == 0 {
            timer.invalidate()
            gameOver()
        } else {
            seconds -= 1
            timerLabel.text = "\(seconds)"
        }
    }
    
    // Resets the timer
    func resetTimer() {
        timer.invalidate()
        seconds = 30
        timerLabel.text = "\(seconds)"
    }
    
    /////////////////////
    // MARK: - GAME OVER
    ////////////////////

    func gameOver() {
        // Store the score in UserDefaults
        let defaults = UserDefaults.standard
        defaults.set(score, forKey: "score")
        
        // Go back to the Home View Controller
        self.dismiss(animated: true, completion: nil)
    }
    
    //////////////////////////////
    // MARK: - MISSILES & TARGETS
    /////////////////////////////
    
    // Creates quadcopter1 or quadcopter2 node and 'fires' it
    func fireMissile(type : String) {
        var node = SCNNode()
        
        // Create node
        node = createMissile(type: type)
        
        // Get the users position and direction
        let (direction, position) = self.getUserVector()
        node.position = position
        
        var nodeDirection = SCNVector3()
        
        switch type {
        case "bullet":
            nodeDirection  = SCNVector3(direction.x * 4, direction.y * 4, direction.z * 4)
            node.physicsBody?.applyForce(nodeDirection, at: SCNVector3(0.1, 0, 0), asImpulse: true)
            playSound(sound: "mossbergShotgun", format: "wav")
            
            // Remove ball after 3 seconds
            let disapear = SCNAction.fadeOut(duration: 0.3)
            node.runAction(.sequence([.wait(duration: 6), disapear]))
        default:
            nodeDirection = direction
        }
        
        // Move node
        node.physicsBody?.applyForce(nodeDirection, asImpulse: true)
        
        // Add node to scene
        sceneView.scene.rootNode.addChildNode(node)
    }
    
    // Create nodes
    func createMissile(type: String) -> SCNNode {
        var node = SCNNode()
        
        // Using case statement to allow variations of scale and rotations
        switch type {
        case "bullet":
            let scene = SCNScene(named: "art.scnassets/bullet.scn")
            node = (scene?.rootNode.childNode(withName: "bullet", recursively: true)!)!
            node.scale = SCNVector3(0.2, 0.2, 0.2)
            node.name = "bullet"
        default:
            node = SCNNode()
        }
        
        // The physics body governs how the object interacts with other objects and its environment
        node.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        node.physicsBody?.isAffectedByGravity = false
        
        // These bitmasks used to define "collisions" with other objects
        node.physicsBody?.categoryBitMask = CollisionCategory.missileCategory.rawValue
        node.physicsBody?.collisionBitMask = CollisionCategory.targetCategory.rawValue
        return node
    }
    
    // Adds 100 objects to the scene, spins them, and places them at random positions around the player
    func addTargetNodes(){
        for index in 1...100 {
            var node = SCNNode()
            
            if(index > 9) && (index % 10 == 0) {
                let scene = SCNScene(named: "art.scnassets/quadcopter2.scn")
                node = (scene?.rootNode.childNode(withName: "quadcopter2", recursively: true)!)!
                node.scale = SCNVector3(1.0, 1.0, 1.0)
                node.name = "quadcopter2"
            } else {
                let scene = SCNScene(named: "art.scnassets/quadcopter1.scn")
                node = (scene?.rootNode.childNode(withName: "quadcopter1", recursively: true)!)!
                node.scale = SCNVector3(1.0, 1.0, 1.0)
                node.name = "quadcopter1"
            }
            
            node.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
            node.physicsBody?.isAffectedByGravity = false
            
            // Place randomly, within thresholds
            node.position = SCNVector3(randomFloat(min: -10, max: 10), randomFloat(min: -4, max: 5), randomFloat(min: -10, max: 10))
            
            // Rotate
            let action: SCNAction = SCNAction.rotate(by: .pi, around: SCNVector3(0, 1, 0), duration: 1.0)
            let forever = SCNAction.repeatForever(action)
            node.runAction(forever)
            
            // For the collision detection
            node.physicsBody?.categoryBitMask = CollisionCategory.targetCategory.rawValue
            node.physicsBody?.contactTestBitMask = CollisionCategory.missileCategory.rawValue
            
            // Add to scene
            sceneView.scene.rootNode.addChildNode(node)
        }
    }
    
    // Create random float between specified ranges
    func randomFloat(min: Float, max: Float) -> Float {
        return (Float(arc4random()) / 0xFFFFFFFF) * (max - min) + min
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        // Release any cached data, images, etc that aren't in use
    }
    
    /////////////////////////////
    // MARK: - ARSCNVIEWDELEGATE
    ////////////////////////////
    
    /*
        // Override to create and configure nodes for anchors added to the view's session.
        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            let node = SCNNode()
     
            return node
        }
     */
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
    }
    
    ////////////////////////////
    // MARK: - CONTACT DELEGATE
    ///////////////////////////
    
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        print("** Collision!! " + contact.nodeA.name! + " hit " + contact.nodeB.name!)
        
        if contact.nodeA.physicsBody?.categoryBitMask == CollisionCategory.targetCategory.rawValue
            || contact.nodeB.physicsBody?.categoryBitMask == CollisionCategory.targetCategory.rawValue {
            if(contact.nodeA.name! == "quadcopter2" || contact.nodeB.name! == "quadcopter2") {
                score += 5
            } else {
                score += 1
            }
            
            DispatchQueue.main.async {
                contact.nodeA.removeFromParentNode()
                contact.nodeB.removeFromParentNode()
                self.scoreLabel.text = String(self.score)
            }
            
            playSound(sound: "explosion", format: "mp3")
            let explosion = SCNParticleSystem(named: "fire", inDirectory: nil)
            contact.nodeB.addParticleSystem(explosion!)
        }
    }
    
    //////////////////
    // MARK: - SOUNDS
    /////////////////
    
    var player: AVAudioPlayer?
    
    // Audio player method for bullet and explosion
    func playSound(sound : String, format: String) {
        guard let url = Bundle.main.url(forResource: sound, withExtension: format) else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            
            player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.mp3.rawValue)
            
            guard let player = player else { return }
            player.play()
        } catch let error {
            print(error.localizedDescription)
        }
    }
    
    // Background music method
    func playBackgroundMusic(){
        let audioNode = SCNNode()
        let audioSource = SCNAudioSource(fileNamed: "expartigh.aiff")!
        let audioPlayer = SCNAudioPlayer(source: audioSource)
        
        audioNode.addAudioPlayer(audioPlayer)
        
        let play = SCNAction.playAudio(audioSource, waitForCompletion: true)
        audioNode.runAction(play)
        sceneView.scene.rootNode.addChildNode(audioNode)
    }
}

struct CollisionCategory: OptionSet {
    let rawValue: Int
    
    static let missileCategory  = CollisionCategory(rawValue: 1 << 0)
    static let targetCategory = CollisionCategory(rawValue: 1 << 1)
    static let otherCategory = CollisionCategory(rawValue: 1 << 2)
}

// Helper function inserted by Swift 4.2 migrator
fileprivate func convertFromAVAudioSessionCategory(_ input: AVAudioSession.Category) -> String {
    return input.rawValue
}
