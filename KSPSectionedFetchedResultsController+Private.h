//
//  KPSectionedFetchedResultsController+Private.h
//  KSPFetchedResultsController
//
//  Created by Konstantin Pavlikhin on 05.09.14.
//  Copyright (c) 2015 Konstantin Pavlikhin. All rights reserved.
//

#import "KSPSectionedFetchedResultsController.h"

@interface KSPSectionedFetchedResultsController ()

@property(readwrite, strong, nonatomic, nonnull) NSString* sectionNameKeyPath;

@property(readwrite, strong, nonatomic, nullable) NSArray<KSPTableSection*>* sections;

@end
