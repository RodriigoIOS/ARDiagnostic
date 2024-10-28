// App created by Rodrigo Garcia

import UIKit
import ARKit
import Vision
import AVFoundation

class ViewController: UIViewController, ARSessionDelegate {
    
    var arView: ARSCNView!
    var handPoseRequest: VNDetectHumanHandPoseRequest?
    var handNodes: [VNHumanHandPoseObservation.JointName: SCNNode] = [:]
    
    var flashIcon: UIButton! // Alterado para UIButton
    var isFlashOn = false // Estado do flash

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Inicializando a view de AR
        arView = ARSCNView(frame: self.view.frame)
        self.view.addSubview(arView)
        
        // Configurando a sessão AR
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics = .personSegmentationWithDepth
        arView.session.run(configuration)
        
        // Definindo o delegate da sessão
        arView.session.delegate = self
        
        // Chamando a função setupVision
        setupVision()
        
        // Configurando o botão de flash
        setupFlashButton()
    }
    
    func setupVision() {
        handPoseRequest = VNDetectHumanHandPoseRequest(completionHandler: { [weak self] request, error in
            if let results = request.results as? [VNHumanHandPoseObservation] {
                for observation in results {
                    self?.processHandPose(observation)
                }
            }
        })
    }
    
    func setupFlashButton() {
        flashIcon = UIButton(type: .custom)
        flashIcon.setImage(UIImage(named: "flash_icon"), for: .normal) // Imagem do ícone do flash
        flashIcon.translatesAutoresizingMaskIntoConstraints = false
        
        self.view.addSubview(flashIcon)
        
        // Configurando constraints para posicionar o botão
        NSLayoutConstraint.activate([
            flashIcon.widthAnchor.constraint(equalToConstant: 30),
            flashIcon.heightAnchor.constraint(equalToConstant: 30),
            flashIcon.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -50),
            flashIcon.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 40)
        ])
        
        // Adicionando ação ao botão de flash
        flashIcon.addTarget(self, action: #selector(toggleFlash), for: .touchUpInside)
        flashIcon.isUserInteractionEnabled = true // Garante que o botão pode interagir
    }
    
    @objc func toggleFlash() {
        print("Botão de flash pressionado") // Debug: Log para verificar se o botão está sendo pressionado
        isFlashOn.toggle()
        setFlashMode(isOn: isFlashOn)
        
        // Mudando a imagem do botão dependendo do estado do flash
        let flashImage = isFlashOn ? UIImage(named: "flash_on_icon") : UIImage(named: "flash_icon")
        flashIcon.setImage(flashImage, for: .normal)
    }

    func setFlashMode(isOn: Bool) {
        guard let captureDevice = AVCaptureDevice.default(for: .video) else {
            print("Dispositivo não suporta câmera.")
            return
        }
        
        if captureDevice.hasTorch {
            do {
                try captureDevice.lockForConfiguration()
                captureDevice.torchMode = isOn ? .on : .off
                captureDevice.unlockForConfiguration()
            } catch {
                print("Erro ao ativar/desativar o flash: \(error.localizedDescription)")
            }
        } else {
            print("Este dispositivo não possui flash.")
        }
    }
    
    func updateNode(_ node: SCNNode, withPosition position: CGPoint) {
        // Converte a posição CGPoint em uma posição 3D no espaço AR
        let hitTestResults = arView.hitTest(position, types: [.featurePoint])
        
        if let result = hitTestResults.first {
            let translation = result.worldTransform.columns.3
            let newPosition = SCNVector3(translation.x, translation.y, translation.z)
            node.position = newPosition // Atualiza a posição do nó
        }
    }

    func processHandPose(_ observation: VNHumanHandPoseObservation) {
        // Lista de pares de articulações para conectar
        let jointPairs: [(VNHumanHandPoseObservation.JointName, VNHumanHandPoseObservation.JointName)] = [
            (.wrist, .thumbCMC), (.thumbCMC, .thumbMP), (.thumbMP, .thumbTip),
            (.wrist, .indexMCP), (.indexMCP, .indexPIP), (.indexPIP, .indexDIP), (.indexDIP, .indexTip),
            (.wrist, .middleMCP), (.middleMCP, .middlePIP), (.middlePIP, .middleDIP), (.middleDIP, .middleTip),
            (.wrist, .ringMCP), (.ringMCP, .ringPIP), (.ringPIP, .ringDIP), (.ringDIP, .ringTip),
            (.wrist, .littleMCP), (.littleMCP, .littlePIP), (.littlePIP, .littleDIP), (.littleDIP, .littleTip)
        ]
        
        for (startJoint, endJoint) in jointPairs {
            guard
                let startPoint = try? observation.recognizedPoint(startJoint),
                let endPoint = try? observation.recognizedPoint(endJoint),
                startPoint.confidence > 0.5, endPoint.confidence > 0.5
            else { continue }
            
            // Verifica e cria os nós de esfera para os pontos da mão
            if handNodes[startJoint] == nil {
                let startNode = createHandNode(color: .blue)
                updateNode(startNode, withPosition: startPoint.location)
                handNodes[startJoint] = startNode
                arView.scene.rootNode.addChildNode(startNode)
            }
            
            if handNodes[endJoint] == nil {
                let endNode = createHandNode(color: .blue)
                updateNode(endNode, withPosition: endPoint.location)
                handNodes[endJoint] = endNode
                arView.scene.rootNode.addChildNode(endNode)
            }

            // Conecta os pontos com uma linha
            let lineNode = createLineNode(from: handNodes[startJoint]!, to: handNodes[endJoint]!)
            arView.scene.rootNode.addChildNode(lineNode)
        }
    }

    func createHandNode(color: UIColor) -> SCNNode {
        let sphereGeometry = SCNSphere(radius: 0.02)
        sphereGeometry.firstMaterial?.diffuse.contents = color
        return SCNNode(geometry: sphereGeometry)
    }

    func createLineNode(from startNode: SCNNode, to endNode: SCNNode) -> SCNNode {
        let lineGeometry = SCNCylinder(radius: 0.002, height: CGFloat(distance(from: startNode, to: endNode)))
        lineGeometry.firstMaterial?.diffuse.contents = UIColor.gray
        
        let lineNode = SCNNode(geometry: lineGeometry)
        lineNode.position = midpoint(between: startNode.position, and: endNode.position)
        lineNode.look(at: endNode.position) // Alinha a linha com os pontos de início e fim
        
        return lineNode
    }

    // Função de ajuda para calcular a distância entre dois nós
    func distance(from startNode: SCNNode, to endNode: SCNNode) -> Float {
        let dx = endNode.position.x - startNode.position.x
        let dy = endNode.position.y - startNode.position.y
        let dz = endNode.position.z - startNode.position.z
        return sqrt(dx*dx + dy*dy + dz*dz)
    }

    // Função para calcular o ponto médio entre dois nós
    func midpoint(between start: SCNVector3, and end: SCNVector3) -> SCNVector3 {
        return SCNVector3((start.x + end.x) / 2, (start.y + end.y) / 2, (start.z + end.z) / 2)
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let pixelBuffer = frame.capturedImage
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        do {
            try requestHandler.perform([handPoseRequest!])
        } catch {
            print("Erro ao executar o request: \(error)")
        }
    }
}
