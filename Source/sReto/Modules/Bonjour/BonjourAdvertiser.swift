//
//  BonjourAdvertiser.swift
//  sReto
//
//  Created by Julian Asamer on 25/07/14.
//  Copyright (c) 2014 LS1 TUM. All rights reserved.
//

import Foundation
import CocoaAsyncSocket

protocol BonjourServiceAdvertiserDelegate : class {
    func didPublish()
    func didNotPublish()
    func didStop()
}

protocol BonjourServiceAdvertiser : class {
    weak var delegate: BonjourServiceAdvertiserDelegate? { get set }
    
    func startAdvertising(name: String, type: String, port: UInt)
    func stopAdvertising()
}

class BonjourAdvertiser: NSObject, Advertiser, GCDAsyncSocketDelegate, BonjourServiceAdvertiserDelegate {
    var advertiserDelegate: AdvertiserDelegate?
    var isAdvertising: Bool = false
    
    private let networkType: String
    private let dispatchQueue: dispatch_queue_t
    private var advertiser: BonjourServiceAdvertiser
    private let recommendedPacketSize: Int
    //this array stores connections that would be deinitialized otherwised
    private var connections = [UnderlyingConnection]()
    
    var acceptingSocket: GCDAsyncSocket?
    
    init(networkType: String, dispatchQueue: dispatch_queue_t, advertiser: BonjourServiceAdvertiser, recommendedPacketSize: Int) {
        self.networkType = networkType
        self.dispatchQueue = dispatchQueue
        self.advertiser = advertiser
        self.recommendedPacketSize = recommendedPacketSize
        
        super.init()
    }
    
    func startAdvertising(identifier : UUID) {
        let acceptingSocket = GCDAsyncSocket(delegate: self, delegateQueue: dispatchQueue, socketQueue: dispatchQueue)
        self.acceptingSocket = acceptingSocket
        
        var error : NSError? = nil
        do {
            try acceptingSocket.acceptOnPort(0)
        } catch let error1 as NSError {
            error = error1
            log(.High, error: "An error occured when trying to listen for incoming connections: \(error)")
            return
        }
        
        self.advertiser.delegate = self
        self.advertiser.startAdvertising(identifier.UUIDString, type: self.networkType, port: UInt(acceptingSocket.localPort))
        self.isAdvertising = true
    }
    
    func stopAdvertising() {
        self.acceptingSocket?.disconnect()
        self.advertiser.stopAdvertising()
        self.isAdvertising = false
        self.connections.removeAll()
    }
    
    func socket(sock: GCDAsyncSocket!, didAcceptNewSocket newSocket: GCDAsyncSocket!) {
        let connection = AsyncSocketUnderlyingConnection(socket: newSocket, recommendedPacketSize: 32*1024)
        connections.append(connection)
        if let delegate = self.advertiserDelegate {
            delegate.handleConnection(self, connection: connection)
        }
        else {
            log(.High, error: "Received incoming connection, but there's no delegate set.")
        }
    }
    
    func didPublish() {
        self.advertiserDelegate?.didStartAdvertising(self)
    }
    
    func didNotPublish() {
        log(.Medium, error: "failed to publish advertisement.")
        self.isAdvertising = false
        self.advertiser.stopAdvertising()
    }
    
    func didStop() {
        self.advertiserDelegate?.didStopAdvertising(self)
        self.isAdvertising = false
    }
}
