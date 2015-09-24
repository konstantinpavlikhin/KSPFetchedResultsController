//
//  KPTableSection.h
//  KSPFetchedResultsController
//
//  Created by Konstantin Pavlikhin on 05.09.14.
//  Copyright (c) 2015 Konstantin Pavlikhin. All rights reserved.
//

#import <Foundation/Foundation.h>

// * * *.

@class NSManagedObject;

// * * *.

@interface KSPTableSection : NSObject

- (instancetype) initWithSectionName: (NSObject*) sectionName nestedObjects: (NSArray<NSManagedObject*>*) nestedObjects;

@property(readwrite, copy, nonatomic) NSObject* sectionName;

// Collection KVO-compatible property.
@property(readonly) NSArray<__kindof NSManagedObject*>* nestedObjects;

- (void) insertObject: (NSManagedObject*) object inNestedObjectsAtIndex: (NSUInteger) index;

@end
