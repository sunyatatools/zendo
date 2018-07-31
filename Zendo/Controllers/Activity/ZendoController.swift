//
//  ViewController.swift
//  Zazen
//
//  Created by Douglas Purdy on 12/27/17.
//  Copyright © 2017 zenbf. All rights reserved.
//

import UIKit
import HealthKit
import Mixpanel

class ZendoController: UITableViewController {
    
    //segue
    private let showDetailSegue = "showDetail"
    
    var currentWorkout: HKWorkout?
    var samples = [HKSample]()
    let hkType = HKObjectType.workoutType()
    let healthStore = ZBFHealthKit.healthStore
    //let hkPredicate = HKQuery.predicateForObjects(from: HKSource.default())
    let hkPredicate = HKQuery.predicateForWorkouts(with: .mindAndBody)
    
    let url = URL(string: "http://zenbf.org/zendo")!
    
    override open var shouldAutorotate: Bool {
        return false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Mixpanel.mainInstance().track(event: "zendo_enter")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        Mixpanel.mainInstance().track(event: "zendo_exit")
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        
        let delete = UITableViewRowAction(style: .destructive, title: "Delete") { action, indexPath in
            let workout = self.samples[indexPath.row] as! HKWorkout
            ZBFHealthKit.deleteWorkout(workout: workout)
            
            self.samples.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
        
        return [delete]
    }
    
    
    func populateTable() {
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let hkQuery = HKSampleQuery.init(sampleType: hkType, predicate: hkPredicate,
                                         limit: HealthKit.HKObjectQueryNoLimit,
                                         sortDescriptors: [sortDescriptor],
                                         resultsHandler: { query, results, error in
                                            
                                            if let error = error {
                                                print(error)
                                            } else {
                                                DispatchQueue.main.async() {
                                                    self.samples = results!
                                                    
                                                    Mixpanel.mainInstance().track(event: "zendo_session_load",
                                                                                  properties: ["session_count" : self.samples.count ])
                                                    
                                                    if((results?.count)! > 0) {
                                                        self.tableView.backgroundView = nil
                                                        self.tableView.separatorStyle = .singleLine
                                                        self.tableView.reloadData();
                                                    } else {
                                                        let image = UIImage(named: "nux")
                                                        let frame = self.tableView.frame
                                                        
                                                        let nuxView = UIImageView(frame: frame)
                                                        nuxView.image = image;
                                                        nuxView.contentMode = .scaleAspectFit
                                                        
                                                        self.tableView.separatorStyle = .none
                                                        self.tableView.backgroundView = nuxView
                                                    }
                                                }
                                            }
                                            
        })
        
        healthStore.execute(hkQuery)
        /*
         let oQuery = HKObserverQuery.init(sampleType: hkType, predicate: hkPredicate) {
         
         query,results,error in
         
         if(error != nil )
         {
         print(error!)
         
         }
         else
         {
         DispatchQueue.main.async()
         {
         //#todo(dataflow): think the behavior of HKOQ is different on IOS12?
         //self.tableView.reloadData()
         //self.populateTable()
         }
         }
         }
         
         healthStore.execute(oQuery)
         */
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == showDetailSegue,
            let destination = segue.destination as? ZazenController,
            let idx = tableView.indexPathForSelectedRow?.row {
            
            let sample = samples[idx]
            
            currentWorkout = (sample as! HKWorkout)
            destination.workout = currentWorkout
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        populateTable()
        
        tableView.estimatedRowHeight = 60.0
        tableView.rowHeight = UITableViewAutomaticDimension
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
       
        /*
        let sample = samples![indexPath.row];
        
        currentWorkout = (sample as! HKWorkout);
        
        let details = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "zazen-controller") as! ZazenController
        
        details.workout = currentWorkout
        
        present(details, animated: true, completion: {});
        */
        
    }
    
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let sample = samples[indexPath.row]
        currentWorkout = (sample as! HKWorkout)
    }
    
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return samples.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ZendoTableViewCell.reuseIdentifierCell, for: indexPath) as! ZendoTableViewCell
        cell.workout = (samples[indexPath.row] as! HKWorkout)
        
        return cell
    }
    
    @IBAction func onReload(_ sender: UIRefreshControl) {
        self.populateTable()
        sender.endRefreshing()
    }
    
    @IBAction func onNewSession(_ sender: Any){
        ZBFHealthKit.getPermissions()
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .mindAndBody
        configuration.locationType = .unknown
        
        healthStore.startWatchApp(with: configuration) { success, error in
                guard success else {
                    print (error.debugDescription)
                    return
                }
        }
        
        Mixpanel.mainInstance().time(event: "new_session")
        
        let alert = UIAlertController(title: "Starting Watch App",
                                      message: "Deep Press + Exit when complete.", preferredStyle: .actionSheet)
        
        let ok = UIAlertAction(title: "Done", style: .default) { action in
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(1) ) {
                Mixpanel.mainInstance().track(event: "new_session")
                self.populateTable()
            }
        }
        
        alert.addAction(ok)
        present(alert, animated: true)
    }
    
    @IBAction func buddhaClick(_ sender: Any) {
        showController("buddha-controller")
    }
    
    @IBAction func sanghaClick(_ sender: Any) {
        showController("sangha-controller")
    }
    
    @IBAction func dharmaClick(_ sender: Any) {
        showController("dharma-controller")
    }
    
    func showController(_ named: String) {
        Mixpanel.mainInstance().time(event: named + "_enter")
        
        let controller = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: named)
        
        present(controller, animated: true) {
            Mixpanel.mainInstance().track(event: named + "_exit")
        }
    }
    
    @IBAction func actionClick(_ sender: Any) {
        
        #if DEBUG
        
        //self.exportAll() #todo: make this change the attachment when in debug mode
       
        #endif
        
        let vc = UIActivityViewController(activityItems: [url as Any], applicationActivities: [])
        
        vc.excludedActivityTypes = [
            UIActivityType.assignToContact,
            UIActivityType.saveToCameraRoll,
            UIActivityType.postToFlickr,
            UIActivityType.postToVimeo,
            UIActivityType.postToTencentWeibo,
            UIActivityType.postToTwitter,
            UIActivityType.postToFacebook,
            UIActivityType.openInIBooks
        ]
        
        present(vc, animated: true, completion: nil)
        
    }
    
    func exportAll() {
        
        var samples = [[String : Any]]()
        
        let hkPredicate = HKQuery.predicateForObjects(from: HKSource.default())
        let mindfulSessionType = HKObjectType.categoryType(forIdentifier: .mindfulSession)!
        
        let sortDescriptor = NSSortDescriptor(key:HKSampleSortIdentifierStartDate, ascending: false)
        
        
        let hkQuery = HKSampleQuery.init(sampleType: mindfulSessionType, predicate: hkPredicate, limit: HealthKit.HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor], resultsHandler: {query, results, error in
            
            if error != nil  {
                print(error!)
            } else {
                DispatchQueue.main.sync() {
                    samples = results!.map { dictionary in
                        var dict: [String: String] = [:]
                        dictionary.metadata!.forEach { (key, value) in dict[key] = "\(value)" }
                        return dict
                    }
                    
                    let fileName = "zendo.json"
                    let path = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
                    
                    let outputStream = OutputStream(url: path!, append: false)
                    
                    outputStream?.open()
                    
                    JSONSerialization.writeJSONObject(
                        samples,
                        to: outputStream!,
                        options: JSONSerialization.WritingOptions.prettyPrinted,
                        error: nil)
                    
                    outputStream?.close()
                    
                    let vc = UIActivityViewController(activityItems: [path as Any], applicationActivities: [])
                    
                    vc.excludedActivityTypes = [
                        UIActivityType.assignToContact,
                        UIActivityType.saveToCameraRoll,
                        UIActivityType.postToFlickr,
                        UIActivityType.postToVimeo,
                        UIActivityType.postToTencentWeibo,
                        UIActivityType.postToTwitter,
                        UIActivityType.postToFacebook,
                        UIActivityType.openInIBooks
                    ]
                    
                    self.present(vc, animated: true, completion: nil)
                    
                }
            }
            
        })
        
        HKHealthStore().execute(hkQuery)
        
    }
    
}