//
//  MPDocumentSettingsWindowController.m
//  MacPass
//
//  Created by Michael Starke on 26.06.13.
//  Copyright (c) 2013 HicknHack Software GmbH. All rights reserved.
//

#import "MPDatabaseSettingsWindowController.h"
#import "MPDocument.h"
#import "MPDocumentWindowController.h"
#import "MPDatabaseVersion.h"
#import "MPIconHelper.h"
#import "MPSettingsHelper.h"
#import "MPNumericalInputFormatter.h"

#import "KPKXmlFormat.h"
#import "KPKGroup.h"
#import "KPKTree.h"
#import "KPKMetaData.h"
#import "KPKNode+IconImage.h"
#import "KPKCompositeKey.h"

#import "HNHRoundedTextField.h"
#import "HNHRoundedSecureTextField.h"

#import "NSString+Empty.h"


@interface MPDatabaseSettingsWindowController () {
  MPDocument *_document;
  NSString *_missingFeature;
}
@property (nonatomic,assign) BOOL trashEnabled;

@end

@implementation MPDatabaseSettingsWindowController

- (id)init {
  self = [self initWithDocument:nil];
  return self;
}

- (id)initWithDocument:(MPDocument *)document {
  self = [super initWithWindowNibName:@"DatabaseSettingsWindow"];
  if(self) {
    _document = document;
    _missingFeature = NSLocalizedString(@"KDBX_ONLY_FEATURE", "Feature only available in kdbx databases");
  }
  return self;
}

- (void)windowDidLoad {
  [super windowDidLoad];
  
  NSAssert(_document != nil, @"Document needs to be present");
    
  [self.sectionTabView setDelegate:self];
  [self.encryptionRoundsTextField setFormatter:[[MPNumericalInputFormatter alloc] init]];
}

#pragma mark Actions

- (IBAction)save:(id)sender {
  /* General */
  KPKMetaData *metaData = _document.tree.metaData;
  metaData.databaseDescription = [self.databaseDescriptionTextView string];
  metaData.databaseName = [self.databaseNameTextField stringValue];

  NSInteger compressionIndex = [self.databaseCompressionPopupButton indexOfSelectedItem];
  if(compressionIndex >= KPKCompressionNone && compressionIndex < KPKCompressionCount) {
    metaData.compressionAlgorithm = compressionIndex;
  }
  NSColor *databaseColor = [self.databaseColorColorWell color];
  if([databaseColor isEqual:[NSColor clearColor]]) {
    metaData.color = nil;
  }
  else {
    metaData.color = databaseColor;
  }
    
  /* Advanced */
  metaData.recycleBinEnabled = self.trashEnabled;
  NSMenuItem *trashMenuItem = [self.selectRecycleBinGroupPopUpButton selectedItem];
  KPKGroup *trashGroup = [trashMenuItem representedObject];
  _document.trash  = trashGroup;
  
  NSMenuItem *templateMenuItem = [self.templateGroupPopUpButton selectedItem];
  KPKGroup *templateGroup = [templateMenuItem representedObject];
  _document.templates = templateGroup;
  
  BOOL protectNotes = [self.protectNotesCheckButton state] == NSOnState;
  BOOL protectPassword = [self.protectPasswortCheckButton state] == NSOnState;
  BOOL protectTitle = [self.protectTitleCheckButton state] == NSOnState;
  BOOL protectURL = [self.protectURLCheckButton state] == NSOnState;
  BOOL protectUsername = [self.protectUserNameCheckButton state] == NSOnState;
  
  metaData.protectNotes = protectNotes;
  metaData.protectPassword = protectPassword;
  metaData.protectTitle = protectTitle;
  metaData.protectUrl = protectURL;
  metaData.protectUserName = protectUsername;
  metaData.defaultUserName = [self.defaultUsernameTextField stringValue];
  
  /*
   NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:protectNotes forKey:kMPSettingsKeyLegacyHideNotes];
    [defaults setBool:protectPassword forKey:kMPSettingsKeyLegacyHidePassword];
    [defaults setBool:protectTitle forKey:kMPSettingsKeyLegacyHideTitle];
    [defaults setBool:protectURL forKey:kMPSettingsKeyLegacyHideURL];
    [defaults setBool:protectUsername forKey:kMPSettingsKeyLegacyHideUsername];
    [defaults synchronize];
   */
  [self close:nil];
}

- (IBAction)close:(id)sender {
  [self dismissSheet:0];
}

- (IBAction)benchmarkRounds:(id)sender {
  [self.benchmarkButton setEnabled:NO];
  [KPKCompositeKey benchmarkTransformationRounds:1 completionHandler:^(NSUInteger rounds) {
    [self.encryptionRoundsTextField setIntegerValue:rounds];
    [self.benchmarkButton setEnabled:YES];
  }];
}

- (void)updateView {
  if(!self.isDirty) {
    return;
  }
  /* Update all stuff that might have changed */
  KPKMetaData *metaData = _document.tree.metaData;
  [self _setupDatabaseTab:metaData];
  [self _setupProtectionTab:metaData];
  [self _setupAdvancedTab:_document.tree];
  self.isDirty = NO;
}

- (void)showSettingsTab:(MPDatabaseSettingsTab)tab {
  /*
   We need to make sure the window is loaded
   so we just call the the getter and led the loading commence
   */
  if(![self window]) {
    return;
  }
  [self.sectionTabView selectTabViewItemAtIndex:tab];
}

#pragma mark NSTableViewDelegate
- (BOOL)tabView:(NSTabView *)tabView shouldSelectTabViewItem:(NSTabViewItem *)tabViewItem {
  NSUInteger index = [tabView indexOfTabViewItem:tabViewItem];
  switch ((MPDatabaseSettingsTab)index) {
    case MPDatabaseSettingsTabSecurity:
    case MPDatabaseSettingsTabAdvanced:
    case MPDatabaseSettingsTabGeneral:
      return YES;
      
    default:
      return NO;
  }
}

#pragma mark Private Helper
- (void)_setupDatabaseTab:(KPKMetaData *)metaData {
  [self.databaseNameTextField setStringValue:metaData.databaseName];
  [self.databaseDescriptionTextView setString:metaData.databaseDescription];
  [self.databaseCompressionPopupButton selectItemAtIndex:metaData.compressionAlgorithm];
  NSColor *databaseColor = metaData.color ? metaData.color : [NSColor clearColor];
  [self.databaseColorColorWell setColor:databaseColor];
}

- (void)_setupProtectionTab:(KPKMetaData *)metaData {
  [self.protectNotesCheckButton setState:metaData.protectNotes ? NSOnState : NSOffState ];
  [self.protectPasswortCheckButton setState:metaData.protectPassword ? NSOnState : NSOffState];
  [self.protectTitleCheckButton setState:metaData.protectTitle ? NSOnState : NSOffState];
  [self.protectURLCheckButton setState:metaData.protectUrl ? NSOnState : NSOffState];
  [self.protectUserNameCheckButton setState:metaData.protectUserName ? NSOnState : NSOffState];
  [self.encryptionRoundsTextField setIntegerValue:metaData.rounds];
  [self.benchmarkButton setEnabled:YES];
}

- (void)_setupAdvancedTab:(KPKTree *)tree {
  [self.enableRecycleBinCheckButton bind:NSValueBinding toObject:self withKeyPath:@"trashEnabled" options:nil];
  [self.selectRecycleBinGroupPopUpButton bind:NSEnabledBinding toObject:self withKeyPath:@"trashEnabled" options:nil];
  [self _updateTrashFolders:tree];
  
  [self.defaultUsernameTextField setStringValue:tree.metaData.defaultUserName];
  [self.defaultUsernameTextField setEditable:YES];
  [self _updateTemplateGroup:tree];
}

- (void)_updateFirstResponder {
  NSTabViewItem *selected = [self.sectionTabView selectedTabViewItem];
  MPDatabaseSettingsTab tab = [[self.sectionTabView tabViewItems] indexOfObject:selected];
  
  switch(tab) {
    case MPDatabaseSettingsTabAdvanced:
      [[self window] makeFirstResponder:self.defaultUsernameTextField];
      break;
      
    case MPDatabaseSettingsTabSecurity:
      [[self window] makeFirstResponder:self.protectTitleCheckButton];
      break;
      
    case MPDatabaseSettingsTabGeneral:
      [[self window] makeFirstResponder:self.databaseNameTextField];
      break;
  }
}

- (void)_updateTrashFolders:(KPKTree *)tree {
  NSMenu *menu = [self _buildTrashTreeMenu:tree];
  [self.selectRecycleBinGroupPopUpButton setMenu:menu];
}

- (void)_updateTemplateGroup:(KPKTree *)tree {
  NSMenu *menu = [self _buildTemplateTreeMenu:tree];
  [self.templateGroupPopUpButton setMenu:menu];
}

- (NSMenu *)_buildTrashTreeMenu:(KPKTree *)tree {
  NSMenu *menu = [self _buildTreeMenu:tree preselect:tree.metaData.recycleBinUuid];
  
  NSMenuItem *selectItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"AUTOCREATE_TRASH_FOLDER", @"Menu item for automatic trash creation")
                                                      action:NULL
                                               keyEquivalent:@""];
  [selectItem setEnabled:YES];
  [menu insertItem:selectItem atIndex:0];
  
  return menu;
}

- (NSMenu *)_buildTemplateTreeMenu:(KPKTree *)tree {
  NSMenu *menu = [self _buildTreeMenu:tree preselect:tree.metaData.entryTemplatesGroup];
  
  NSMenuItem *selectItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"NO_TEMPLATE_GROUP", @"Menu item to reset the template groups")
                                                      action:NULL
                                               keyEquivalent:@""];
  [selectItem setEnabled:YES];
  [menu insertItem:selectItem atIndex:0];
  
  return menu;
}


- (NSMenu *)_buildTreeMenu:(KPKTree *)tree preselect:(NSUUID *)uuid {
  NSMenu *menu = [[NSMenu alloc] init];
  [menu setAutoenablesItems:NO];
  for(KPKGroup *group in tree.root.groups) {
    [self _insertMenuItemsForGroup:group atLevel:0 inMenu:menu preselect:uuid];
  }
  return menu;
}

- (void)_insertMenuItemsForGroup:(KPKGroup *)group atLevel:(NSUInteger)level inMenu:(NSMenu *)menu preselect:(NSUUID *)uuid{
  NSMenuItem *groupItem = [[NSMenuItem alloc] init];
  [groupItem setImage:group.iconImage];
  [groupItem setTitle:group.name];
  [groupItem setRepresentedObject:group];
  [groupItem setEnabled:YES];
  if(uuid && [group.uuid isEqual:uuid]) {
    [groupItem setState:NSOnState];
  }
  [groupItem setIndentationLevel:level];
  [menu addItem:groupItem];
  for(KPKGroup *childGroup in group.groups) {
    [self _insertMenuItemsForGroup:childGroup atLevel:level + 1 inMenu:menu preselect:uuid];
  }
}

@end
