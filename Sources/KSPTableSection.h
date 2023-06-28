//
//  KPTableSection.h
//  KSPFetchedResultsController
//
//  Created by Konstantin Pavlikhin on 05.09.14.
//  Copyright (c) 2016 Konstantin Pavlikhin. All rights reserved.
//

#import <Foundation/Foundation.h>

// * * *.

@class NSManagedObject;

// * * *.

@interface KSPTableSection : NSObject

- (nonnull instancetype) init NS_UNAVAILABLE;

- (nonnull instancetype) initWithSectionName: (nonnull NSObject*) sectionName nestedObjects: (nullable NSArray<NSManagedObject*>*) nestedObjects NS_DESIGNATED_INITIALIZER;

@property(readwrite, copy, nonatomic, nonnull) NSObject* sectionName;

// Collection KVO-compatible property.
@property(readonly, nonatomic, nullable) NSArray<__kindof NSManagedObject*>* nestedObjects;

- (void) insertObject: (nonnull NSManagedObject*) object inNestedObjectsAtIndex: (NSUInteger) index;

@end
