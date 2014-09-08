//
//  KPSectionedFetchedResultsController+Private.h
//  CoreDataPlayground
//
//  Created by Konstantin Pavlikhin on 05.09.14.
//  Copyright (c) 2014 Konstantin Pavlikhin. All rights reserved.
//

#import "KPSectionedFetchedResultsController.h"

@interface KPSectionedFetchedResultsController ()

@property(readwrite, strong, nonatomic) NSString* sectionNameKeyPath;

@property(readwrite, strong, nonatomic) NSArray* sections;

@end
