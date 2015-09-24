//
//  KPSectionedFetchedResultsController.h
//  KSPFetchedResultsController
//
//  Created by Konstantin Pavlikhin on 05.09.14.
//  Copyright (c) 2015 Konstantin Pavlikhin. All rights reserved.
//

#import "KSPFetchedResultsController+Private.h"

// * * *.

@protocol KSPSectionedFetchedResultsControllerDelegate;

@class KSPTableSection;

// * * *.

// Этот класс делался с прицелом на использование в качестве датасурса NSOutlineView.
@interface KSPSectionedFetchedResultsController : KSPFetchedResultsController

// Do not call this initializer when using KPSectionedFetchedResultsController subclass.
- (nullable instancetype) initWithFetchRequest: (nonnull NSFetchRequest*) fetchRequest managedObjectContext: (nonnull NSManagedObjectContext*) context UNAVAILABLE_ATTRIBUTE;

- (nullable instancetype) initWithFetchRequest: (nonnull NSFetchRequest*) fetchRequest managedObjectContext: (nonnull NSManagedObjectContext*) context sectionNameKeyPath: (nonnull NSString*) sectionNameKeyPath NS_DESIGNATED_INITIALIZER;

// Почему оно выдает варнинг при указании одного только KPSectionedFetchedResultsControllerDelegate?
@property(readwrite, weak, nonatomic, nullable) id<KSPFetchedResultsControllerDelegate, KSPSectionedFetchedResultsControllerDelegate> delegate;

@property(readonly, strong, nonatomic, nonnull) NSString* sectionNameKeyPath;

@property(readonly, strong, nonatomic, nullable) NSArray<KSPTableSection*>* sections;

@end
