//
//  KPSectionedFetchedResultsController.h
//  KSPFetchedResultsController
//
//  Created by Konstantin Pavlikhin on 05.09.14.
//  Copyright (c) 2016 Konstantin Pavlikhin. All rights reserved.
//

#import "KSPFetchedResultsController+Private.h"

// * * *.

@protocol KSPSectionedFetchedResultsControllerDelegate;

@class KSPTableSection;

// * * *.

// This class was aimed to be used as a datasource of an NSOutlineView.
@interface KSPSectionedFetchedResultsController : KSPFetchedResultsController

// Do not call this initializer when using KPSectionedFetchedResultsController subclass.
- (nullable instancetype) initWithFetchRequest: (nonnull NSFetchRequest*) fetchRequest managedObjectContext: (nonnull NSManagedObjectContext*) context NS_UNAVAILABLE;

- (nullable instancetype) initWithFetchRequest: (nonnull NSFetchRequest*) fetchRequest managedObjectContext: (nonnull NSManagedObjectContext*) context sectionNameKeyPath: (nonnull NSString*) sectionNameKeyPath NS_DESIGNATED_INITIALIZER;

@property(readwrite, weak, nonatomic, nullable) id<KSPFetchedResultsControllerDelegate, KSPSectionedFetchedResultsControllerDelegate> delegate;

@property(readonly, strong, nonatomic, nonnull) NSString* sectionNameKeyPath;

@property(readonly, strong, nonatomic, nullable) NSArray<KSPTableSection*>* sections;

@end
