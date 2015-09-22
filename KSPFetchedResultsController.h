//
//  KSPFetchedResultsController.h
//  KSPFetchedResultsController
//
//  Created by Konstantin Pavlikhin on 04.09.14.
//  Copyright (c) 2015 Konstantin Pavlikhin. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// * * *.

@class NSFetchRequest;

@class NSManagedObjectContext;

@protocol KSPFetchedResultsControllerDelegate;

// * * *.

// Этот класс делался с прицелом на использование в качестве датасурса NSTableView.
@interface KSPFetchedResultsController : NSObject

- (instancetype) init NS_UNAVAILABLE;

- (instancetype) initWithFetchRequest: (NSFetchRequest*) fetchRequest managedObjectContext: (NSManagedObjectContext*) context NS_DESIGNATED_INITIALIZER;

- (BOOL) performFetch: (NSError* __autoreleasing*) error;

@property(readonly, nonatomic) NSFetchRequest* fetchRequest;

@property(readonly, nonatomic) NSManagedObjectContext* managedObjectContext;

@property(readwrite, weak, nonatomic) id<KSPFetchedResultsControllerDelegate> delegate;

// Collection KVO-compatible property.
@property(readonly, nonatomic) NSArray<__kindof NSManagedObject*>* fetchedObjects;

@end
