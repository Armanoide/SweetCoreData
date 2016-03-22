//
//  SweetCoreData.swift
//  Running
//
//  Created by Norbert Billa on 26/11/2015.
//  Copyright © 2015 norbert-billa. All rights reserved.
//

import CoreData
import Foundation

class SweetCoreData {
    
    // MARK: - SINGLETON
    
    class var shared: SweetCoreData {
        struct Static {
            static var instance: SweetCoreData?
            static var token: dispatch_once_t = 0
        }
        dispatch_once(&Static.token) {
            Static.instance = SweetCoreData()
        }
        return Static.instance!
    }
    
    var nameDatabase: String!
    
    func configure(nameDatabase: String) {
        self.nameDatabase = nameDatabase
    }
    
    private func preformChangeToDefaultContext(object object: SweetCoreDataEntity) -> SweetCoreDataEntity {
        
        let keysObject = object.entity.attributesByName.getKeys()
        let __dictObject = object.dictionaryWithValuesForKeys(keysObject)
        var dictObject : [String: AnyObject] = [:]
        
        let entity = NSManagedObject(entity: object.entity, insertIntoManagedObjectContext: self.managedObjectContext) as! SweetCoreDataEntity
        
        for __ in __dictObject {
            if __.1 is SweetCoreDataEntity {
                dictObject[__.0] = self.preformChangeToDefaultContext(object: __.1 as! SweetCoreDataEntity)
            } else {
                dictObject[__.0] = __.1
            }
        }
        
        entity.setValuesForKeysWithDictionary(dictObject)
        return entity
    }
    
    func copyObject(object object: SweetCoreDataEntity, insideObject: SweetCoreDataEntity ) {
        
        let keysObject = object.entity.attributesByName.getKeys()
        let __dictObject = object.dictionaryWithValuesForKeys(keysObject)
        insideObject.setValuesForKeysWithDictionary(__dictObject)
    }
    
    private func getPK(object object: SweetCoreDataEntity) -> String {
        let representationID =  object.objectID.URIRepresentation().absoluteString
        return NSString(string: representationID).lastPathComponent
    }
    
    func flush(object __object: SweetCoreDataEntity) {
        
        var object = __object
        
        if object.managedObjectContext != self.managedObjectContext {
            object = self.preformChangeToDefaultContext(object: object)
        }
        
        
        if let field = object.ORMIndexField()  {
            if let value = object.valueForKey(field) {
                let fetchRequest = NSFetchRequest(entityName:object.entity.name!)
                fetchRequest.predicate = NSPredicate(format: "\(field) = \(value)")
                fetchRequest.sortDescriptors = []
                
                do {
                    let result = try self.managedObjectContext.executeFetchRequest(fetchRequest)
                    
                    for __ in result as! [SweetCoreDataEntity] {
                        if __.objectID.persistentStore != nil && getPK(object: __) != getPK(object: object){
                            
                            self.copyObject(object: object, insideObject: __)
                            self.remove(object: object)
                            return
                        }
                    }
                    
                    
                } catch {  }
            }
        }
        
        self.managedObjectContext.processPendingChanges()
        self.managedObjectContext.insertObject(object)
        self.saveContext()
        self.managedObjectContext.processPendingChanges()
    }
    
    func remove(object object: SweetCoreDataEntity) {
        self.managedObjectContext.processPendingChanges()
        self.managedObjectContext.deleteObject(object)
        self.managedObjectContext.processPendingChanges()
        self.saveContext()
    }
    
    
    
    lazy var applicationDocumentsDirectory: NSURL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "com.billa.dsdfsdfsdf" in the application's documents Application Support directory.
        let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        return urls[urls.count-1]
    }()
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = NSBundle.mainBundle().URLForResource(self.nameDatabase, withExtension: "momd")!
        return NSManagedObjectModel(contentsOfURL: modelURL)!
    }()
    
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        // The persistent store coordinator for the application. This implementation creates and returns a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        // Create the coordinator and store
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.URLByAppendingPathComponent("\(self.nameDatabase).sqlite")
        print(url)
        var failureReason = "There was an error creating or loading the application's saved data."
        
        let optionsPersistentStore = [NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true]
        do {
            try coordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: optionsPersistentStore)
        } catch {
            // Report any error we got.
            var dict = [String: AnyObject]()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
            dict[NSLocalizedFailureReasonErrorKey] = failureReason
            
            dict[NSUnderlyingErrorKey] = error as NSError
            let wrappedError = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            // Replace this with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog("Unresolved error \(wrappedError), \(wrappedError.userInfo)")
            abort()
        }
        
        return coordinator
    }()
    
    var temporaryManagedObjectContext : NSManagedObjectContext = NSManagedObjectContext()
    
    lazy var managedObjectContext: NSManagedObjectContext = {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()
    
    // MARK: - Core Data Saving support
    
    func saveContext () {
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                NSLog("Unresolved error \(nserror), \(nserror.userInfo)")
                abort()
            }
        }
    }
    
    
    
}