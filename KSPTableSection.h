//
//  KPTableSection.h
//  KSPFetchedResultsController
//
//  Created by Konstantin Pavlikhin on 05.09.14.
//  Copyright (c) 2014 Konstantin Pavlikhin. All rights reserved.
//

#import <Foundation/Foundation.h>

// * * *.

@class NSManagedObject;

// * * *.

@interface KSPTableSection : NSObject

- (instancetype) initWithSectionName: (NSObject*) sectionName nestedObjects: (NSArray*) nestedObjects;

@property(readwrite, copy, nonatomic) NSObject* sectionName;

// Collection KVO-compatible property.
@property(readonly) NSArray* nestedObjects;

- (void) insertObject: (NSManagedObject*) object inSectionsAtIndex: (NSUInteger) index;

@end
