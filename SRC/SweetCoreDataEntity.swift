//
//  SweetCoreDataEntity.swift
//  Running
//
//  Created by Norbert Billa on 26/11/2015.
//  Copyright © 2015 norbert-billa. All rights reserved.
//

import CoreData
import Foundation

enum WHERE_COMPARE : String {
    case EQUAL               = "="
    case NOT_EQUAL           = "!="
    case LESS                = "<"
    case GREATER             = ">"
    case CONTAIN_INSENSITIVE = "CONTAINS[cd]"
}

typealias OrdersByColumn = (column:String, ASC:Bool)

struct WhereQueryInfo {
    
    var column  : String!
    var compare : WHERE_COMPARE!
    var value   : AnyObject!
    
}

struct WhereQuery {
    
    var query: WhereQueryInfo!
    var orQuery: WQB<WhereQuery!>?
    
}

class WQB<T> {
    
    var boxed: T
    init(_ W: T) { boxed = W }
    
}

@objc protocol SweetCoreDataEntityDelegate : class {
    
    static func create() -> SweetCoreDataEntity
    
    optional func ORMIndexField() -> String?
}

class SweetCoreDataEntity : NSManagedObject, SweetCoreDataEntityDelegate {
    
    func ORMIndexField() -> String? { return nil }
    
    func postCreate() {}
    
    private class func classNameAsString(obj: Any) -> String {
        return _stdlib_getDemangledTypeName(obj).componentsSeparatedByString(".").last!
    }
    
    private class func __NAME_CLASS__() -> AnyObject { return self }
    
    
    static func create() ->  SweetCoreDataEntity {
        
        //        return NSClassFromString("\(__NAME_CLASS__())")
        
        let temporaryManagedContext = SweetCoreData.shared.temporaryManagedObjectContext
        let managedContext          = SweetCoreData.shared.managedObjectContext
        let entityDescription       = NSEntityDescription.entityForName(self.classNameAsString(self.__NAME_CLASS__()), inManagedObjectContext: managedContext)
        let entity                  = NSManagedObject(entity: entityDescription!, insertIntoManagedObjectContext:  temporaryManagedContext ) as! SweetCoreDataEntity
        entity.postCreate()
        return entity
    }
    
    private func performCopy(object object :SweetCoreDataEntity)  -> SweetCoreDataEntity{
        let managedContextTemporary = SweetCoreData.shared.temporaryManagedObjectContext
        
        let keysObject = self.entity.attributesByName.getKeys()
        let __dictObject = self.dictionaryWithValuesForKeys(keysObject)
        var dictObject : [String: AnyObject] = [:]
        
        let entity = NSManagedObject(entity: self.entity, insertIntoManagedObjectContext: managedContextTemporary) as! SweetCoreDataEntity
        
        for __ in __dictObject {
            if __.1 is SweetCoreDataEntity {
                dictObject[__.0] = self.performCopy(object: __.1 as! SweetCoreDataEntity)
            } else {
                dictObject[__.0] = __.1
            }
        }
        
        entity.setValuesForKeysWithDictionary(dictObject)
        return entity
    }
    
    func copyEntity() -> SweetCoreDataEntity {
        return self.performCopy(object: self)
    }
    
    func flush () {
        SweetCoreData.shared.flush(object: self)
    }
    
    func remove() {
        SweetCoreData.shared.remove(object: self)
    }
    
    static func deleteAllEntities() {
    
        for entitiy in self.getEntityAll() {
            SweetCoreData.shared.remove(object: entitiy)
        }
    }

    static func deleteAllEntities(except except: [NSNumber]) {
        for entitiy in self.getEntityAll() {
            if let index = entitiy.ORMIndexField() {
                if let index = Int64(index) {
                    if except.contains(NSNumber(longLong: index)) {
                        continue
                    }
                }
            }
            SweetCoreData.shared.remove(object: entitiy)
        }
    }

    
    static func getEntityAll() -> [SweetCoreDataEntity] {
        return self.getEntitiesWhere()
    }
    
    
    
    private static func getPredicateQuery(_predicateQuery: String, wheres: WhereQueryInfo, modeOr:Bool) -> (predicateQuery: String, specialArg: CVarArgType?){
        
        var predicateQuery = _predicateQuery
        let length = predicateQuery.characters.count
        
        var specialArg : CVarArgType!
        var partValue = ""
        if wheres.value is NSDate {
            specialArg = wheres.value as! CVarArgType
            //            specialArgs.append(wheres.query.value as! CVarArgType)
            partValue = "%@"
        } else if wheres.value is NSNumber || wheres.value is Int || wheres.value is Int64 || wheres.value is Int8 {
            partValue = "\(wheres.value)"
        } else {
            partValue = "'\(wheres.value)'"
        }
        
        let parOr = (!modeOr ? "(" : "")
        
        if length == 0 {
            predicateQuery = "\(parOr) \(wheres.column) \(wheres.compare.rawValue) \(partValue) "
        } else {
            predicateQuery = "\(predicateQuery) \((modeOr ? "OR" : "AND" )) \((!modeOr ? "(" : "")) \(wheres.column) \(wheres.compare.rawValue) \(partValue)"
        }
        
        return (predicateQuery, specialArg)
    }
    
    /**
     Description return item found by filter in the databese
     
     - parameter wheres: [WhereQuery(column  : String!, compare : WHERE_COMPARE!, value   : AnyObject!)]

     - parameter ordersBy: [(column:String, ASC:Bool)]
     
     - returns: [SweetCoreDataEntity]
     */
    static func getEntitiesWhere(wheres wheres :[WhereQuery] = [], ordersBy:[OrdersByColumn] = []) -> [SweetCoreDataEntity] {
        
        var specialArgs                 : [CVarArgType] = []
        var predicate                   : NSPredicate!
        var sortDescriptors             : [NSSortDescriptor] = []
        let managedObjectContext        : NSManagedObjectContext = SweetCoreData.shared.managedObjectContext
        let fetchRequest                : NSFetchRequest = NSFetchRequest(entityName:"\(self.__NAME_CLASS__())")
        var predicateQuery = ""
        for __ in ordersBy as [OrdersByColumn] {
            sortDescriptors.append(NSSortDescriptor(key: __.column, ascending: __.ASC))
        }
        if wheres.count > 0 {
            for __ in wheres {
                
                let p = self.getPredicateQuery(predicateQuery, wheres: __.query, modeOr: false)
                if p.specialArg != nil {
                    specialArgs.append(p.specialArg!)
                }
                predicateQuery = p.predicateQuery
                
                var or = __.orQuery
                while (or != nil) {
                    
                    let pOr = self.getPredicateQuery(predicateQuery, wheres: or!.boxed.query, modeOr: true)
                    if pOr.specialArg != nil {
                        specialArgs.append(pOr.specialArg!)
                    }
                    predicateQuery = pOr.predicateQuery
                    or = or!.boxed.orQuery
                }
                
                predicateQuery = "\(predicateQuery) )"
            }
            predicate = withVaList(specialArgs) { (pointer: CVaListPointer) -> NSPredicate in
                return NSPredicate(format: predicateQuery, arguments: pointer)
            }
        }
        
        fetchRequest.predicate       = predicate
        fetchRequest.sortDescriptors = sortDescriptors
        
        do {
            let results = try managedObjectContext.executeFetchRequest(fetchRequest) as! [SweetCoreDataEntity]
            return results
        } catch {}
        
        return []
    }
    
    
    // MARK: - RELATION MAPPING ENTITY
    
    private func ThrowErrorIfFieldExist(field :String) -> Void {
        let attributes = self.entity.attributesByName as [NSString: NSAttributeDescription]
        for attributeName in attributes.keys  {
            if attributeName == field {
                return
            }
        }
        assert(true, "Field \(field) no exist for entity \(self.entity.name)")
    }
    
    private func getStringIDS(field :String) -> String {
        
        ThrowErrorIfFieldExist(field)
        return self.valueForKey(field as String) as? String ?? ""
    }
    
    func getId(field :String) -> NSNumber {
        ThrowErrorIfFieldExist(field)
        return self.valueForKey(field) as! NSNumber
    }
    
    func getIds(field :String) -> [NSNumber] {
        
        var ids : [NSNumber] = []
        
        let arrayIds = NSString(string: self.getStringIDS(field)).componentsSeparatedByString(";")
        for id in arrayIds {
            if id != "" {
                let formatter = NSNumberFormatter()
                formatter.numberStyle = .DecimalStyle
                ids.append(formatter.numberFromString(id)!)
            }
        }
        return ids
    }
    
    func removeIds(field field : String, idEntiy: NSNumber){
        let ids = self.getIds(field)
        self.setValue("", forKey: field)
        
        for id in ids {
            if !(idEntiy.compare(id) == NSComparisonResult.OrderedSame) {
                self.appendIds(field: field, idEntiy: id)
            }
        }
    }
    
    func appendIds(field field : String, idEntiy: NSNumber){
        
        let __  = self.getStringIDS(field as String)
        self.setValue("\(__);\(idEntiy);", forKey: field as String)
    }
    
    private func ORM_getRelationEntityFromDB<T: SweetCoreDataEntity>(type type : T.Type, field: String, ids: [NSNumber]) -> [T]
    {
        
        var _whereQuery_ : WhereQuery!
        var currentWhereOr : WQB<WhereQuery!>?
        let c = T.create()
        
        
        for var i = 0; i < ids.count; i++ {
            
            if i == 0 {
                currentWhereOr = i + 1 < ids.count ? WQB(WhereQuery(query: nil, orQuery: nil)) : nil
                _whereQuery_ = WhereQuery(query: WhereQueryInfo(column:c.ORMIndexField()!, compare:.EQUAL, value: ids.get(i)), orQuery: currentWhereOr)

            } else {
                
                currentWhereOr!.boxed.query = WhereQueryInfo(column:c.ORMIndexField()!, compare:.EQUAL, value: ids.get(i))
                
                currentWhereOr!.boxed.orQuery = i + 1 > ids.count ? WQB(WhereQuery(query: nil, orQuery: nil)) : nil
                currentWhereOr = currentWhereOr!.boxed.orQuery
            }
            
        }
        
        
        if _whereQuery_ != nil {
                return T.getEntitiesWhere(wheres: [_whereQuery_]) as! [T]
        } else {
            return []
        }
    }
    
    func ORM_getRelationEntities<T: SweetCoreDataEntity>(type type :T.Type, isManyIds: Bool = true, field: String,callRessource:( id: NSNumber ,endCall:()-> Void  )-> Void , completion:(entities:[T])-> Void) {
        
        let ids = isManyIds ? self.getIds(field) : [self.getId(field)]
        let groupEntity  = self.ORM_getRelationEntityFromDB(type: type, field: field, ids: ids)
        
        
        if groupEntity.count == ids.count {
            completion(entities: groupEntity)
        } else {
            
            let  group                  : dispatch_group_t  = dispatch_group_create()
            
            for id in ids  {
                dispatch_group_enter(group)
                callRessource(id: id, endCall: { () -> Void in
                    dispatch_group_leave(group)
                })
            }

            dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) { () -> Void in
                
                
                let groupEntity  = self.ORM_getRelationEntityFromDB(type: type, field: field, ids: ids)
                
                if ids.count == groupEntity.count {
                    completion(entities: groupEntity)
                } else {
                    NSTimer.delay(3, closure: { () -> () in
                        // RE CALL SELF
                        self.ORM_getRelationEntities(type: type, field: field, callRessource: callRessource, completion: completion)
                    })
                }
            }
        }
    }
    
    
}