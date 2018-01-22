// Copyright (c) 2016 Vectorform LLC
// http://www.vectorform.com/
// https://github.com/CocoaHeadsDetroit/ARKit2DTracking
//
// ARKit2DTracking
// ViewController.swift
//

import UIKit
import SceneKit
import ARKit
import Vision

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate,UIGestureRecognizerDelegate {
    
    let ids = ["ID16","ID37","ID53","image_4","ID85"]
    let names = ["Kinetic Energy","Work-Energy Theorem","Mechanical Energy","Work","Potential Energy"]
    let problems = ["KineticEnergyProblem.png","WorkEnergyTheoremProblem.png","MechanicalEnergyProblem.png","WorkProblem.png","potentialenergyproblem.png"]
    let picIDs = ["image_1","image_2","image_3","image_4","image_0"]
    let textureIDs = ["texture_0.png","texture_1.png","texture_2.png","texture_3.png","texture.png"]
    var isProblem = [false,false,false,false,false]
    
    // MARK: - Properties
    
    @IBOutlet var sceneView: ARSCNView!
    
    var detectedDataAnchor: ARAnchor?
    var processing = false
    
    // MARK: - View Setup
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Set the session's delegate
        sceneView.session.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Enable horizontal plane detection
        configuration.planeDetection = .horizontal
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(gestureRecognize:)))
        tapGesture.delegate = self
        let gestureRecognizers = NSMutableArray()
        gestureRecognizers.add(tapGesture)
        sceneView.gestureRecognizers = gestureRecognizers as? [UIGestureRecognizer]
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    // MARK: - ARSessionDelegate
    
    
    
    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
        // Only run one Vision request at a time
        if self.processing {
            return
        }
        
        self.processing = true
        
        // Create a Barcode Detection Request
        let request = VNDetectBarcodesRequest { (request, error) in
            
            // Get the first result out of the results, if there are any
            if let results = request.results, let result = results.first as? VNBarcodeObservation {
                
                if let desc=result.barcodeDescriptor as? CIQRCodeDescriptor{
                    if(desc.bytes != nil){
                        let content = String(data: (desc.bytes)!, encoding: .utf8)
                    var j = 0
                    var url = ""
                    for i in content!{
                        if j >= 11 && j < (content?.count)! - 1{
                     url += String(i)
                        }
                        j += 1
                    }
                    //print(url)
                    }
                    else{
                       // print("Nil!!!")
                    }
                }

                
                // Get the bounding box for the bar code and find the center
                var rect = result.boundingBox
                
                // Flip coordinates
                rect = rect.applying(CGAffineTransform(scaleX: 1, y: -1))
                rect = rect.applying(CGAffineTransform(translationX: 0, y: 1))
                
                // Get center
                let center = CGPoint(x: rect.midX, y: rect.midY)
                
                // Go back to the main thread
                DispatchQueue.main.async {
                    
                    // Perform a hit test on the ARFrame to find a surface
                    let hitTestResults = frame.hitTest(center, types: [.featurePoint/*, .estimatedHorizontalPlane, .existingPlane, .existingPlaneUsingExtent*/] )
                    
                    // If we have a result, process it
                    if let hitTestResult = hitTestResults.first {
                        
                        // If we already have an anchor, update the position of the attached node
                        if let detectedDataAnchor = self.detectedDataAnchor,
                            let node = self.sceneView.node(for: detectedDataAnchor) {
                                
                                node.transform = SCNMatrix4(hitTestResult.worldTransform)
                            
                        } else {
                            // Create an anchor. The node will be created in delegate methods
                            self.detectedDataAnchor = ARAnchor(transform: hitTestResult.worldTransform)
                            self.sceneView.session.add(anchor: self.detectedDataAnchor!)
                        }
                    }
                    
                    // Set processing flag off
                    self.processing = false
                }
                
            } else {
                // Set processing flag off
                self.processing = false
            }
        }
        
        // Process the request in the background
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Set it to recognize QR code only
                request.symbologies = [.QR]
                
                // Create a request handler using the captured image from the ARFrame
                let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: frame.capturedImage,
                                                                options: [:])
                // Process the request
                try imageRequestHandler.perform([request])
            } catch {
                
            }
        }
    }
    
    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        
        // If this is our anchor, create a node
        if self.detectedDataAnchor?.identifier == anchor.identifier {
            
            // Model to display
            guard let virtualObjectScene = SCNScene(named: "MillimeterTest.dae", inDirectory: "Models.scnassets/3DModels/obj") else {
                print("3D model not found!")
                return nil
            }
            
            let wrapperNode = SCNNode()
            
            for child in virtualObjectScene.rootNode.childNodes {
                child.geometry?.firstMaterial?.lightingModel = .physicallyBased
                child.movabilityHint = .movable
                wrapperNode.addChildNode(child)
            }
            
            // Set its position based off the anchor
            wrapperNode.transform = SCNMatrix4(anchor.transform)
            
            return wrapperNode
 
        }

            
        return nil
    }
    @objc func handleTap(gestureRecognize: UIGestureRecognizer) {
        let p:CGPoint = gestureRecognize.location(in: sceneView)
        
        let hitResults:[SCNHitTestResult] = sceneView.hitTest(p, options: nil)
        if(hitResults.count > 0){
            let result:SCNHitTestResult = hitResults[0]
            if (ids .contains(result.node.name!)){
                print("Found!")
                let mat = SCNMaterial()
                let masterID = ids .index(of: result.node.name!)!
                if(isProblem[masterID]){
                    if(masterID != 4){
                    mat.diffuse.contents = UIImage(named: "Models.scnassets/3DModels/obj/"+textureIDs[masterID])
                    self.sceneView.scene.rootNode.childNodes[2].childNodes[0].childNode(withName: picIDs[masterID], recursively: true)?.geometry?.materials = [mat]
                    }
                    else{
                        self.sceneView.scene.rootNode.childNodes[2].childNodes[0].childNode(withName: "SPHERE_POTENTIAL", recursively: true)?.removeFromParentNode()
                        self.sceneView.scene.rootNode.childNodes[2].childNodes[0].childNode(withName: "SPHERE_POTENTIAL_TEXT", recursively: true)?.removeFromParentNode()
                        self.sceneView.scene.rootNode.childNodes[2].childNodes[0].childNode(withName: picIDs[masterID], recursively: true)?.isHidden = false
                        self.sceneView.scene.rootNode.childNodes[2].childNodes[0].childNode(withName: ids[masterID], recursively: true)?.opacity = 1
                    }
                } else{
                    if(masterID != 4){
                mat.diffuse.contents = UIImage(named: "Models.scnassets/3DModels/obj/"+problems[masterID])
                self.sceneView.scene.rootNode.childNodes[2].childNodes[0].childNode(withName: picIDs[masterID], recursively: true)?.geometry?.materials = [mat]
                    } else{
                        let block = self.sceneView.scene.rootNode.childNodes[2].childNodes[0].childNode(withName: picIDs[masterID], recursively: true)
                        self.sceneView.scene.rootNode.childNodes[2].childNodes[0].childNode(withName: picIDs[masterID], recursively: true)?.isHidden = true
                        self.sceneView.scene.rootNode.childNodes[2].childNodes[0].childNode(withName: ids[masterID], recursively: true)?.opacity = 0.001
                        
                        let sphere = SCNSphere(radius: 5.0)
                        let sphereNode = SCNNode(geometry: sphere)
                        sphereNode.name = "SPHERE_POTENTIAL"
                        sphereNode.geometry!.firstMaterial!.diffuse.contents = UIColor.orange
                        sphereNode.position = (block?.position)!
                        
                        var displayedText = ("Mass: 1.0kg y: 5.0m PE: "+String(5*9.8))
                        
                        let text = SCNText(string:displayedText, extrusionDepth: 2.0)
                        
                        text.firstMaterial?.diffuse.contents = UIColor.green
                        text.font = UIFont(name: "Optima", size: 10)
                        text.containerFrame = CGRect(x: 0, y: 0, width: 20, height: 15)
                        
                        let textNode = SCNNode(geometry: text)
                        textNode.name = "SPHERE_POTENTIAL_TEXT"
                        textNode.position = (block?.position)!
                        
                        self.sceneView.scene.rootNode.childNodes[2].childNodes[0].addChildNode(sphereNode)
                        self.sceneView.scene.rootNode.childNodes[2].childNodes[0].addChildNode(textNode)
                        
                        let fall = SCNAction.customAction(duration: 10, action: {node, time -> () in
                            let y = sphereNode.position.y
                            sphereNode.position = SCNVector3(x: sphereNode.position.x, y:y-0.5,z:sphereNode.position.z)
                            displayedText = "Mass: 1.0kg y: "+String(y+350)+"m PE: "+String((y+350)*9.8)
                            if let scnText = textNode.geometry as? SCNText {
                                scnText.string = displayedText
                            }
                        })
                        
                        sphereNode.runAction(fall)
                        
                        
                    }
                    
                }
                
                isProblem[masterID] = !isProblem[masterID]
            }
        }
    }
}

extension CIQRCodeDescriptor {
    var bytes: Data? {
        return errorCorrectedPayload.withUnsafeBytes { (pointer: UnsafePointer<UInt8>) in
            var cursor = pointer
            
            let representation = (cursor.pointee >> 4) & 0x0f
            guard representation == 4 /* byte encoding */ else { return nil }
            
            var count = (cursor.pointee << 4) & 0xf0
            cursor = cursor.successor()
            count |= (cursor.pointee >> 4) & 0x0f
            
            var out = Data(count: Int(count))
            guard count > 0 else { return out }
            
            var prev = (cursor.pointee << 4) & 0xf0
            for i in 2...errorCorrectedPayload.count {
                if (i - 2) == count { break }
                
                let cursor = pointer.advanced(by: Int(i))
                let byte = cursor.pointee
                let current = prev | ((byte >> 4) & 0x0f)
                out[i - 2] = current
                prev = (cursor.pointee << 4) & 0xf0
            }
            return out
        }
    }
}
