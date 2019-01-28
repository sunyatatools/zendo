//
//  ZBFHealthKit.swift
//  Zendo
//
//  Created by Douglas Purdy on 3/23/18.
//  Copyright © 2018 zenbf. All rights reserved.
//

import UIKit
import HealthKit

public class ZBFHealthKit {
    
    static let healthStore = HKHealthStore()
    
    static let hkReadTypes = hkShareTypes
    
    static let hkShareTypes = Set([heartRateType, mindfulSessionType, workoutType, heartRateSDNNType])
    
    static let heartRateType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!
    
    static let heartRateSDNNType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    
    static let mindfulSessionType = HKObjectType.categoryType(forIdentifier: .mindfulSession)!
    
    static let workoutType = HKObjectType.workoutType()
    
    static let workoutPredicate = HKQuery.predicateForWorkouts(with: .mindAndBody)
    
    class func getPermissions() {
        
        healthStore.handleAuthorizationForExtension { (success, error) in
            
            healthStore.requestAuthorization(
                toShare: hkShareTypes,
                read: hkReadTypes,
                completion: { success, error in
                    
                    if !success && error != nil {
                        print(error.debugDescription);
                    }
                    
            })
        }
    }
    
    
    class func populateCell(workout: HKWorkout, cell: UITableViewCell) {
        
        let minutes = (workout.duration / 60).rounded()
        
        cell.textLabel?.text = "\(Int(minutes).description) min"
        
        cell.detailTextLabel?.text = ZBFHealthKit.format(workout.endDate)
        
        cell.imageView?.contentMode = .scaleAspectFit
        
        cell.imageView?.image = getImage(workout: workout)
        
        let hkType  = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRateVariabilitySDNN)!
        
        let yesterday = Calendar.autoupdatingCurrent.startOfDay(for: workout.endDate)
        
        //Calendar.current.date(byAdding: .day, value: -1, to: workout.endDate)
        
        let hkPredicate = HKQuery.predicateForSamples(withStart: yesterday, end: workout.endDate, options: .strictEndDate)
        
        let options: HKStatisticsOptions = .discreteAverage
        
        let hkQuery = HKStatisticsQuery(quantityType: hkType,
                                        quantitySamplePredicate: hkPredicate,
                                        options: options) { query, result, error in
                                            
                                            if error != nil {
                                                print(error.debugDescription);
                                            }
                                            
                                            if let value = result!.averageQuantity()?.doubleValue(for: HKUnit(from: "ms")) {
                                                
                                                DispatchQueue.main.async() {
                                                    
                                                    let size = (cell.imageView?.image?.size)!
                                                    
                                                    cell.imageView?.image =  generateImageWithText(size: size, text: Int(value).description, fontSize: 33.0)
                                                    
                                                    UIView.animate(withDuration: 2, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
                                                        
                                                        if value < 99 {
                                                            let scale = CGAffineTransform(scaleX: 1 - CGFloat(value/100), y: 1 - CGFloat(value/100))
                                                            
                                                            cell.imageView?.transform = scale
                                                        }
                                                        
                                                        cell.imageView?.transform = CGAffineTransform.identity
                                                        
                                                    }, completion: nil )
                                                    
                                                }
                                            } else {
                                                let size = (cell.imageView?.image?.size)!
                                                
                                                DispatchQueue.main.async() {
                                                    cell.imageView?.image =  generateImageWithText(size: size, text: "00", fontSize: 33.0)
                                                }
                                            }
        }
        
        ZBFHealthKit.healthStore.execute(hkQuery)
        
    }
    
    class func getImage(workout: HKWorkout) -> UIImage {
        
        let image = UIImage(named: "shobogenzo")!
        
        let size = CGSize(width: 100 , height: 100)
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        
        image.draw(in: rect)
        
        let retval: UIImage! = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return retval!
        
    }
    
    class func format(_ date: Date) -> String {
        
        let dateFormatter = DateFormatter()
        
        dateFormatter.timeZone = TimeZone.autoupdatingCurrent
        dateFormatter.setLocalizedDateFormatFromTemplate("YYYY-MM-dd")
        
        let localDate = dateFormatter.string(from: date)
        
        dateFormatter.setLocalizedDateFormatFromTemplate("HH:mm")
        
        let localTime = dateFormatter.string(from: date)
        
        return localDate + " " + localTime
    }
    
    class func generateImageWithText(size: CGSize, text: String, fontSize: CGFloat) -> UIImage {
        let image = UIImage(named: "shobogenzo")!
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFill
        imageView.frame = rect
        imageView.backgroundColor = UIColor.clear
        
        let label = UILabel(frame: rect)
        label.backgroundColor = UIColor.clear
        label.textAlignment = .center
        label.textColor = UIColor.white
        label.text = text
        label.font = UIFont.boldSystemFont(ofSize: fontSize)
        
        UIGraphicsBeginImageContextWithOptions(label.bounds.size, false, 0);
        
        imageView.layer.render(in: UIGraphicsGetCurrentContext()!)
        label.layer.render(in: UIGraphicsGetCurrentContext()!)
        
        let imageWithText = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext();
        
        return imageWithText!
    }
    
    class func deleteWorkout(workout: HKWorkout)
    {
        getMindfulSamples(workout: workout)
        {
            samples in
            
            var objects: [HKSample] = samples.map { $0 }
            
            getHrvSamples(workout: workout)
            {
                    hrvSamples in
                
                    objects.append(contentsOf: hrvSamples)
            
                    objects.append(workout)
                
                    healthStore.delete(objects)
                    {
                        bool, error in
                    
                        if !bool {
                            print(error!)
                        }
                    }
            }
        }
    }
    
    class func getWorkouts(limit: Int, handler: @escaping GetSamplesHandler)
    {
        let hkType = HKObjectType.workoutType()
        let hkPredicate = HKQuery.predicateForObjects(from: HKSource.default())
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let hkQuery = HKSampleQuery(sampleType: hkType,
                                    predicate: hkPredicate,
                                    limit: limit,
                                    sortDescriptors: [sortDescriptor],
                                    resultsHandler:
            {
                query, results, error in
                
                if let error = error
                {
                    print(error)
                }
                else
                {
                   handler(results!)
                }
            })
        
         ZBFHealthKit.healthStore.execute(hkQuery)
        
    }
    
    typealias GetSamplesHandler = ([HKSample]) -> Void
    
    class func getMindfulSamples(workout: HKWorkout, handler: @escaping GetSamplesHandler ) {
        
        //let hkPredicate = HKQuery.predicateForObjects(from: workout as HKWorkout)
        let hkPredicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: .strictStartDate)
        let mindfulSessionType = HKObjectType.categoryType(forIdentifier: .mindfulSession)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        let hkQuery = HKSampleQuery.init(sampleType: mindfulSessionType,
                                         predicate: hkPredicate,
                                         limit: HealthKit.HKObjectQueryNoLimit,
                                         sortDescriptors: [sortDescriptor],
                                         resultsHandler: { query, results, error in
                                            
                                            if error != nil {
                                                print(error!)
                                            } else {
                                                handler(results!)
                                            }
        })
        
        ZBFHealthKit.healthStore.execute(hkQuery)
        
    }
    
    class func getHrvSamples(workout: HKWorkout, handler: @escaping GetSamplesHandler ) {
        
        //let hkPredicate = HKQuery.predicateForObjects(from: workout as HKWorkout)
        let hkPredicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: .strictStartDate)
        let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        let hkQuery = HKSampleQuery.init(sampleType: hrvType,
                                         predicate: hkPredicate,
                                         limit: HealthKit.HKObjectQueryNoLimit,
                                         sortDescriptors: [sortDescriptor],
                                         resultsHandler: { query, results, error in
                                            
                                            if error != nil {
                                                print(error!)
                                            } else {
                                                handler(results!)
                                            }
        })
        
        ZBFHealthKit.healthStore.execute(hkQuery)
        
    }
    
    typealias GetPermissionsHandler = (_ success: Bool, _ error: Error?) -> Void
    
    class func requestHealthAuth(handler: @escaping GetPermissionsHandler)  {
        
        healthStore.handleAuthorizationForExtension { success, error in
            healthStore.requestAuthorization(
                toShare: hkShareTypes,
                read: hkReadTypes,
                completion: handler)
        }
    }
    
    //#todo(debt): need to be consistent in the return of the handler functions?
    typealias SamplesHandler = (_ samples: [Double: Double]?, _ error: Error? ) -> Void
    
    class func getHRVAverage(_ workout: HKWorkout, handler: @escaping SamplesHandler) {
        
        let hkType  = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRateVariabilitySDNN)!
        
        //let yesterday = Calendar.autoupdatingCurrent.startOfDay(for: workout.endDate)
        
        //let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: workout.endDate)
        
        let hkPredicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: .strictStartDate)
        
        let options: HKStatisticsOptions  = [.discreteAverage, .discreteMax, .discreteMin]
        
        let hkQuery = HKStatisticsQuery(quantityType: hkType,
                                        quantitySamplePredicate: hkPredicate,
                                        options: options) { query, result, error in
                                            
                                            if let result = result {
                                                if let value = result.averageQuantity()?.doubleValue(for: HKUnit(from: "ms")) {
                                                    let value = [0.0 : value]
                                                    handler(value, nil)
                                                } else {
                                                    handler(nil, nil)
                                                }
                                            } else {
                                                handler(nil, error)
                                            }
        }
        
        ZBFHealthKit.healthStore.execute(hkQuery)
    }
    
    class func getHRVAverage(start: Date, end: Date, handler: @escaping SamplesHandler) {
        
        let hkType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRateVariabilitySDNN)!
        
        let hkPredicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        let options: HKStatisticsOptions = [HKStatisticsOptions.discreteAverage, HKStatisticsOptions.discreteMax, HKStatisticsOptions.discreteMin]
        
        let hkQuery = HKStatisticsQuery(quantityType: hkType,
                                        quantitySamplePredicate: hkPredicate,
                                        options: options) { query, result, error in
                                            
                                            if let result = result {
                                                if let value = result.averageQuantity()?.doubleValue(for: HKUnit(from: "ms")) {
                                                    let value = [0.0 : value]
                                                    handler(value, nil)
                                                } else {
                                                    handler(nil, nil)
                                                }
                                            } else {
                                                handler(nil, error)
                                            }
        }
        
        ZBFHealthKit.healthStore.execute(hkQuery)
    }
    
    class func getMindfulMinutes(start: Date, end: Date, currentInterval: CurrentInterval, handler: @escaping SamplesHandler) {
        let hkType = HKObjectType.categoryType(forIdentifier: .mindfulSession)!
        
        let hkDatePredicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        let hkSampleQuery = HKSampleQuery(sampleType: hkType,
                                          predicate: hkDatePredicate,
                                          limit: HKObjectQueryNoLimit,
                                          sortDescriptors: [sortDescriptor]) { query, samples, error in
                                            
                                            var entries = [Double: Double]()
                                            var entriesDaysMonth = [Double: [Double]]()
                                            
                                            switch currentInterval {
                                            case .hour:
                                                for i in 0...23 {
                                                    entries[Double(i)] = 0.0
                                                }
                                            case .day:
                                                for i in 1...7 {
                                                    entries[Double(i)] = 0.0
                                                }
                                            case .month:
                                                let calendar = Calendar.current
                                                let range = calendar.range(of: .day, in: .month, for: start)!
                                                for i in 1...range.count {
                                                    entries[Double(i)] = 0.0
                                                }
                                            case .year:
                                                for i in 1...12 {
                                                    entries[Double(i)] = 0.0
                                                }
                                            }
                                            
                                            if let samples = samples/*, !samples.isEmpty*/ {
                                                
                                                let calender = Calendar.current
                                                
                                                samples.forEach( { sample in
                                                    
                                                    let startDate = sample.startDate
                                                    
                                                    let endDate = sample.endDate
                                                    
                                                    let delta = DateInterval(start: startDate, end: endDate)
                                                    
                                                    var key = 0.0
                                                    var keyDay = 0.0
                                                    
                                                    switch currentInterval {
                                                    case .hour:
                                                        key = Double(calender.component(.hour, from: startDate))
                                                    case .day:
                                                        key = Double(calender.component(.weekday, from: startDate))
                                                    case .month:
                                                        key = Double(calender.component(.day, from: startDate))
                                                    case .year:
                                                        keyDay = Double(calender.component(.day, from: startDate))
                                                        key = Double(calender.component(.month, from: startDate))
                                                        
                                                        if var existingValue = entriesDaysMonth[key] {
                                                            existingValue.append(keyDay)
                                                            entriesDaysMonth[key] = existingValue
                                                        } else {
                                                            entriesDaysMonth[key] = [keyDay]
                                                        }
                                                    }
                                                    
                                                    if let existingValue = entries[key] {
                                                        entries[key] = existingValue + delta.duration
                                                    } else {
                                                        entries[key] = delta.duration
                                                    }
                                                    
                                                })
                                                
                                                if currentInterval == .year {
                                                    for i in entriesDaysMonth {
                                                        entriesDaysMonth[i.key] = i.value.removingDuplicates()
                                                    }
                                                    
                                                    for i in entries {
                                                        if entries[i.key] != 0.0 {
                                                            entries[i.key] = (entries[i.key]! / Double(entriesDaysMonth[i.key]!.count))
                                                        }
                                                    }
                                                    
                                                }
                                                
                                                handler(entries, error)
                                                
                                            } else {
                                                handler(entries, error)
                                            }
                                            
        }
        
        healthStore.execute(hkSampleQuery)
    }
    
    class func getHRVSamples(start: Date, end: Date, currentInterval: CurrentInterval, handler: @escaping SamplesHandler) {
        
        var entries = [Double: Double]()
        
        var components = DateComponents()
        
        switch currentInterval {
        case .hour:
            components.hour = 1
        case .day:
            components.day = 1
        case .month:
            components.day = 1
        case .year:
            components.month = 1
        }        
        
        switch currentInterval {
        case .hour:
            for i in 0...23 {
                entries[Double(i)] = 0.0
            }
        case .day:
            for i in 1...7 {
                entries[Double(i)] = 0.0
            }
        case .month:
            let calendar = Calendar.current
            let range = calendar.range(of: .day, in: .month, for: start)!
            for i in 1...range.count {
                entries[Double(i)] = 0.0
            }
        case .year:
            for i in 1...12 {
                entries[Double(i)] = 0.0
            }
        }
        
        
        let hkType  = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRateVariabilitySDNN)!
        
        let query = HKStatisticsCollectionQuery(quantityType: hkType,
                                                quantitySamplePredicate: nil,
                                                options: .discreteAverage,
                                                anchorDate: start,
                                                intervalComponents: components)
        
        query.initialResultsHandler = { query, results, error in
            
            if let statsCollection = results {
                statsCollection.enumerateStatistics(from: start, to: end) { statistics, stop in
                    
                    var avgValue = 0.0
                    
                    if let avgQ = statistics.averageQuantity() {
                        avgValue = avgQ.doubleValue(for: HKUnit(from: "ms"))
                    }
                    
                    var key = 0.0
                    let calender = Calendar.current
                    
                    switch currentInterval {
                    case .hour:
                        key = Double(calender.component(.hour, from: statistics.startDate))
                    case .day:
                        key = Double(calender.component(.weekday, from: statistics.startDate))
                    case .month:
                        key = Double(calender.component(.day, from: statistics.startDate))
                    case .year:
                        key = Double(calender.component(.month, from: statistics.startDate))
                    }
                    
                    entries[key] = avgValue.rounded()
                }
                
                handler(entries, nil)
            } else {
                handler(nil, error)
            }
        }
        
        healthStore.execute(query)
    }
    
    
    class func getBPMSamples(interval: Calendar.Component, value: Int, handler: @escaping SamplesHandler) {
        var entries = [Double: Double]()
        
        let end = Date()
        
        var components = DateComponents()
        
        switch interval {
        case .hour:
            components.hour = 4
        case .day:
            components.day = 1
        case .month:
            components.day = 7
        case .year:
            components.month = 1
        default:
            components.day = 1
        }
        
        let prior = Calendar.current.date(byAdding: interval, value: -(value), to: end)!
        
        let hkType  = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.restingHeartRate)!
        
        let query = HKStatisticsCollectionQuery(quantityType: hkType,
                                                quantitySamplePredicate: nil,
                                                options: HKStatisticsOptions.discreteAverage,
                                                anchorDate: prior,
                                                intervalComponents: components)
        
        query.initialResultsHandler = { query, results, error in
            
            if let statsCollection = results {
                statsCollection.enumerateStatistics(from: prior, to: end ) { statistics, stop in
                    
                    var avgValue = 0.0
                    
                    if let avgQ = statistics.averageQuantity() {
                        avgValue = avgQ.doubleValue(for: HKUnit(from: "count/s"))
                    }
                    
                    let key = statistics.startDate.timeIntervalSince1970
                    
                    entries[key] = (avgValue * 60.0)
                }
                
                handler(entries, nil)
            } else {
                handler(nil, error)
            }
        }
        
        healthStore.execute(query)
    }
}


