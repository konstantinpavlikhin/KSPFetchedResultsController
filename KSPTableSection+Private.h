//
//  KPTableSection+Private.h
//  KSPFetchedResultsController
//
//  Created by Konstantin Pavlikhin on 05.09.14.
//  Copyright (c) 2015 Konstantin Pavlikhin. All rights reserved.
//

#import "KSPTableSection.h"

@interface KSPTableSection ()

@property(readwrite, strong, nonatomic, nullable) NSArray<__kindof NSManagedObject*>* nestedObjects;

// Возвращает нижележащий массив без копирования.
- (nullable NSArray<__kindof NSManagedObject*>*) nestedObjectsNoCopy;

@end
