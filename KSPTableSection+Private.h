//
//  KPTableSection+Private.h
//  CoreDataPlayground
//
//  Created by Konstantin Pavlikhin on 05.09.14.
//  Copyright (c) 2014 Konstantin Pavlikhin. All rights reserved.
//

#import "KSPTableSection.h"

@interface KSPTableSection ()

@property(readwrite, strong, nonatomic) NSArray* nestedObjects;

// Возвращает нижележащий массив без копирования.
- (NSArray*) nestedObjectsNoCopy;

@end
