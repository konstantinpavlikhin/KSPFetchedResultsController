//
//  KSPFetchedResultsController.h
//  KSPFetchedResultsController
//
//  Created by Konstantin Pavlikhin on 04.09.14.
//  Copyright (c) 2016 Konstantin Pavlikhin. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// * * *.

@class NSFetchRequest;

@class NSManagedObjectContext;

@protocol KSPFetchedResultsControllerDelegate;

// * * *.

// This class was aimed to be used as a datasource of an NSTableView.
@interface KSPFetchedResultsController : NSObject

- (nonnull instancetype) init NS_UNAVAILABLE;

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
