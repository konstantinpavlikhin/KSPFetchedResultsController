//
//  KPFetchedResultsController+Private.h
//  CoreDataPlayground
//
//  Created by Konstantin Pavlikhin on 04.09.14.
//  Copyright (c) 2014 Konstantin Pavlikhin. All rights reserved.
//

#import "KPFetchedResultsController.h"

@interface KPFetchedResultsController ()

@property(readwrite, nonatomic) NSFetchRequest* fetchRequest;

@property(readwrite, nonatomic) NSManagedObjectContext* managedObjectContext;

@end
