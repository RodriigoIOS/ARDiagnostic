//
//  ViewController.swift
//  ARDiagnostics App
//
//  Created by Rodrigo on 21/10/24.
//

import UIKit
import ARKit

class ViewController: UIViewController, ARSessionDelegate {
    
    // View de AR
    var arView: ARSCNView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Inicializando a view de AR
        arView = ARSCNView(frame: self.view.frame)
        self.view.addSubview(arView)
        
        // Configurando a sessão AR
        if ARBodyTrackingConfiguration.isSupported {
            startBodyTrackingSession()
        } else {
            print("ARBodyTrackingConfiguration não é suportado neste dispositivo.")
        }
        
        // Definindo o delegate da sessão
        arView.session.delegate = self
    }
    
    func startBodyTrackingSession() {
        let configuration = ARBodyTrackingConfiguration()
        arView.session.run(configuration)
    }
    
    // Função chamada quando o ARKit detecta um bodyAnchor (corpo rastreado)
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let bodyAnchor = anchor as? ARBodyAnchor {
                highlightShoulders(bodyAnchor: bodyAnchor)
            }
        }
    }
    
    // Função chamada a cada atualização do corpo
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let bodyAnchor = anchor as? ARBodyAnchor {
                highlightShoulders(bodyAnchor: bodyAnchor)
            }
        }
    }
    
    // Destaca os ombros do corpo rastreado
    func highlightShoulders(bodyAnchor: ARBodyAnchor) {
        // Posições dos ombros
        guard let leftShoulderTransform = bodyAnchor.skeleton.modelTransform(for: .leftShoulder) else { return }
        guard let rightShoulderTransform = bodyAnchor.skeleton.modelTransform(for: .rightShoulder) else { return }
        
        // Cria uma esfera para marcar o ombro esquerdo
        let leftShoulderNode = createSphereNode(color: .red, transform: leftShoulderTransform)
        arView.scene.rootNode.addChildNode(leftShoulderNode)
        
        // Cria uma esfera para marcar o ombro direito
        let rightShoulderNode = createSphereNode(color: .red, transform: rightShoulderTransform)
        arView.scene.rootNode.addChildNode(rightShoulderNode)
    }
    
    // Função para criar uma esfera e posicioná-la em uma junta específica do corpo
    func createSphereNode(color: UIColor, transform: simd_float4x4) -> SCNNode {
        let sphereGeometry = SCNSphere(radius: 0.05) // Define o tamanho da esfera
        sphereGeometry.firstMaterial?.diffuse.contents = color
        
        let sphereNode = SCNNode(geometry: sphereGeometry)
        sphereNode.simdTransform = transform // Aplica a transformação (posição do corpo)
        
        return sphereNode
    }
}
