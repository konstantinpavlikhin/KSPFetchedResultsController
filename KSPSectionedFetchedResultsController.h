//
//  KPSectionedFetchedResultsController.h
//  CoreDataPlayground
//
//  Created by Konstantin Pavlikhin on 05.09.14.
//  Copyright (c) 2014 Konstantin Pavlikhin. All rights reserved.
//

#import "KSPFetchedResultsController+Private.h"

@protocol KSPSectionedFetchedResultsControllerDelegate;

// Этот класс делался с прицелом на использование в качестве датасурса NSOutlineView.
@interface KSPSectionedFetchedResultsController : KSPFetchedResultsController

// Do not call this initializer when using KPSectionedFetchedResultsController subclass.
- (instancetype) initWithFetchRequest: (NSFetchRequest*) fetchRequest managedObjectContext: (NSManagedObjectContext*) context UNAVAILABLE_ATTRIBUTE;

- (instancetype) initWithFetchRequest: (NSFetchRequest*) fetchRequest managedObjectContext: (NSManagedObjectContext*) context sectionNameKeyPath: (NSString*) sectionNameKeyPath NS_DESIGNATED_INITIALIZER;

// Почему оно выдает варнинг при указании одного только KPSectionedFetchedResultsControllerDelegate?
@property(readwrite, weak, nonatomic) id<KSPFetchedResultsControllerDelegate, KSPSectionedFetchedResultsControllerDelegate> delegate;

@property(readonly, strong, nonatomic) NSString* sectionNameKeyPath;

@property(readonly, strong, nonatomic) NSArray* sections;

@end
