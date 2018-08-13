//
//  ViewController.swift
//  BLEMobileTester
//
//  Created by Ernesto Elsäßer on 28/02/16.
//  Copyright © 2016 ernestoelsaesser. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UITableViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    enum TableState {
        case peripherals
        case services
        case characteristics
    }
    
    let xdkMode = false
    
    var state = TableState.peripherals
    
    var peripherals = [CBPeripheral]()
    var peripheralNames = [CBPeripheral : String]()
    var selectedPeripheral : CBPeripheral?
    var services = [CBService]()
    var selectedService : CBService?
    var characteristics = [CBCharacteristic]()
    var selectedCharacteristic : CBCharacteristic?
    
    var centralManager : CBCentralManager!
    
    //let XDKServiceUUID = CBUUID(string: "00005301-0000-0041-4C50-574953450000")
    let XDKTXUUID = CBUUID(string: "00005302-0000-0041-4C50-574953450000")
    let XDKRXUUID = CBUUID(string: "00005303-0000-0041-4C50-574953450000")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        reset()
    }
    
    func reset() {
        state = TableState.peripherals
        peripherals = [CBPeripheral]()
        peripheralNames = [CBPeripheral : String]()
        selectedPeripheral = nil
        services = [CBService]()
        selectedService = nil
        characteristics = [CBCharacteristic]()
        selectedCharacteristic = nil
        title = "Devices"
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // Table View Delegate
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch(state) {
        case .peripherals:
            return peripherals.count
        case .services:
            return services.count
        case .characteristics:
            return characteristics.count
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")!
        
        if let label = cell.textLabel {
            switch(state) {
            case .peripherals:
                label.text = peripheralNames[peripherals[indexPath.row]]
                break
            case .services:
                label.text = services[indexPath.row].uuid.description
                break
            case .characteristics:
                label.text = characteristics[indexPath.row].uuid.description
                break
            }
        }
        
        return cell
    }
    
    var starting = true
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        switch(state) {
        case .peripherals:
            self.centralManager.stopScan()
            selectedPeripheral = peripherals[indexPath.row]
            selectedPeripheral!.discoverServices(nil)
            break
        case .services:
            selectedService = services[indexPath.row]
            selectedPeripheral!.discoverCharacteristics(nil, for: selectedService!)
            break
        case .characteristics:
            selectedCharacteristic = characteristics[indexPath.row]
            if xdkMode {
                if selectedCharacteristic!.uuid == XDKTXUUID {
                    
                    let string = starting ? "start" : "end"
                    starting = !starting
                    let data = string.data(using: String.Encoding.ascii)!
                    selectedPeripheral!.writeValue(data, for: selectedCharacteristic!, type: CBCharacteristicWriteType.withoutResponse)
                }
                else if selectedCharacteristic!.uuid == XDKRXUUID {
                    selectedPeripheral!.setNotifyValue(true, for: selectedCharacteristic!)
                }
            }
            break
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // CoreBluetooth Delegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {

        if central.state == .poweredOn {
            central.scanForPeripherals(withServices: nil, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        var name = peripheral.name ?? "UNKNOWN"
        if let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
            name = localName
        }
        peripheralNames[peripheral] = name
        peripheral.delegate = self
        self.centralManager.connect(peripheral, options: nil)
    }
    
    // Discover services of the peripheral
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripherals.append(peripheral)
        tableView.reloadData()
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        displayPopup("Error", message: "Connection failed.")
    }
    
    // Check if the service discovered is a valid IR Temperature Service
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {

        for service in peripheral.services! {
            services.append(service)
        }
        
        title = "Services"
        state = TableState.services
        tableView.reloadData()
    }
    
    // Enable notification and sensor for each characteristic of valid service
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    
        for characteristic in service.characteristics! {
            characteristics.append(characteristic)
        }
        
        title = "Characteristics"
        state = TableState.characteristics
        tableView.reloadData()
    }
    
    var first = true
    
    // Get data values when they are updated
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let value = characteristic.value else {
            return
        }
        guard let string = String(data: value, encoding: .ascii) else {
            return
        }
        print(string)
        if first {
            self.displayPopup("Received Data", message: string)
            first = false
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        
        guard let index = peripherals.index(of: peripheral) else {
            return
        }
        
        peripherals.remove(at: index)
        tableView.reloadData()
    }

    func displayPopup(_ title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}

