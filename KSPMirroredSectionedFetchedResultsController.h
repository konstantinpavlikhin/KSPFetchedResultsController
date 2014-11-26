//
//  KSPMirroredSectionedFetchedResultsController.h
//  CoreDataPlayground
//
//  Created by Konstantin Pavlikhin on 25.11.14.
//  Copyright (c) 2014 Konstantin Pavlikhin. All rights reserved.
//

#import "KSPSectionedFetchedResultsController+Private.h"

@interface KSPMirroredSectionedFetchedResultsController : KSPSectionedFetchedResultsController

@property(readonly, strong, nonatomic) NSArray* mirroredFetchedObjects;

// Returns an array of KSPTableSections (you have to call -mirroredNestedObjects on them to get objects in a correct order).
@property(readonly, strong, nonatomic) NSArray* mirroredSections;

@end
