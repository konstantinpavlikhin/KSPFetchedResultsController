//
//  KPTableSection+Private.h
//  CoreDataPlayground
//
//  Created by Konstantin Pavlikhin on 05.09.14.
//  Copyright (c) 2014 Konstantin Pavlikhin. All rights reserved.
//

#import "KPTableSection.h"

@interface KPTableSection ()

@property(readwrite, strong, nonatomic) NSArray* nestedObjects;

// Возвращает нижележащий массив без копирования.
- (NSArray*) nestedObjectsNoCopy;

@end
