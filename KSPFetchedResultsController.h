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

- (nullable instancetype) init NS_UNAVAILABLE;

- (nullable instancetype) initWithFetchRequest: (nonnull NSFetchRequest*) fetchRequest managedObjectContext: (nonnull NSManagedObjectContext*) context NS_DESIGNATED_INITIALIZER;

NS_ASSUME_NONNULL_BEGIN

- (BOOL) performFetch: (NSError* __autoreleasing*) error;

NS_ASSUME_NONNULL_END

@property(readonly, nonatomic, nonnull) NSFetchRequest* fetchRequest;

@property(readonly, nonatomic, nonnull) NSManagedObjectContext* managedObjectContext;

@property(readwrite, weak, nonatomic, nullable) id<KSPFetchedResultsControllerDelegate> delegate;

// Collection KVO-compatible property.
@property(readonly, nonatomic, nullable) NSArray<__kindof NSManagedObject*>* fetchedObjects;

@end
