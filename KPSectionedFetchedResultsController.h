//
//  KPSectionedFetchedResultsController.h
//  CoreDataPlayground
//
//  Created by Konstantin Pavlikhin on 05.09.14.
//  Copyright (c) 2014 Konstantin Pavlikhin. All rights reserved.
//

#import "KPFetchedResultsController+Private.h"

@protocol KPSectionedFetchedResultsControllerDelegate;

// Этот класс делался с прицелом на использование в качестве датасурса NSOutlineView.
@interface KPSectionedFetchedResultsController : KPFetchedResultsController

- (instancetype) initWithFetchRequest: (NSFetchRequest*) fetchRequest managedObjectContext: (NSManagedObjectContext*) context sectionNameKeyPath: (NSString*) sectionNameKeyPath /* NS_DESIGNATED_INITIALIZER */;

@property(readwrite, weak, nonatomic) id<KPSectionedFetchedResultsControllerDelegate> delegate;

@property(readonly, strong, nonatomic) NSString* sectionNameKeyPath;

@property(readonly, strong, nonatomic) NSArray* sections;

@end
