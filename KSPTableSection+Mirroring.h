//
//  KSPTableSection+Mirroring.h
//  KSPFetchedResultsController
//
//  Created by Konstantin Pavlikhin on 26.11.14.
//  Copyright (c) 2014 Konstantin Pavlikhin. All rights reserved.
//

#import "KSPTableSection.h"

@interface KSPTableSection (Mirroring)

// Collection KVO-incompatible property.
@property(readonly, nonatomic) NSArray* mirroredNestedObjects;

@end
