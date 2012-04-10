//
//  SubtitleListController.h
//  SubsDoctor
//
//  Created by Bruno Ferreira on 11/07/24.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QTKit/QTMovieView.h>

#define STEP_PERIOD 5

// TODO: Permitir interpretar as tags de formatações de texto <i> <b> e apresentar o texto formatado na caixa de texto

@interface SubtitleListController : NSObject <NSTableViewDataSource, NSTableViewDelegate>{
    NSMutableArray *subtitleList;
    IBOutlet NSTableView *subtitleTableView;
    IBOutlet NSWindow *appWindow;
    IBOutlet NSWindow *previewWindow;

    // Edição das legendas
    IBOutlet NSTextField *subtitleEditor;
    IBOutlet NSTextField *showTimeField;
    IBOutlet NSTextField *periodTimeField;

    // Visualização do filme
    IBOutlet NSTextField *movieTimeField;
    IBOutlet QTMovieView *movieView;
    
    // Controlos de pesquisa
    IBOutlet NSSearchField *searchField;
    
    // Controlos de sincronismo
    IBOutlet NSSegmentedControl *syncPointsButtons;
    IBOutlet NSButton *autoSelectButton;
	IBOutlet NSSegmentedControl *setSubtitleStartEndButtons;
    
    // Controlador de reprodução
    IBOutlet NSSegmentedControl *playController;
    IBOutlet NSButton *playPreviewButton;
    
    // Menús
    IBOutlet NSMenuItem *saveMenu;
}

typedef enum
{
    sffSrt = 0
} subtitleFileFormat;


// Gravação e carregamento das legendas
- (IBAction)openFile:(id)sender;
- (IBAction)saveFile:(id)sender;
- (IBAction)saveFileAs:(id)sender;
- (IBAction)newSubtitle:(id)sender;

// Edição da legenda
- (IBAction)changeSubtitleShowTime:(id)sender;
- (IBAction)changeSubtitlePeriodTime:(id)sender;
- (IBAction)addRemoveSubtitle:(id)sender;
- (IBAction)setStartEndTime:(id)sender;

// Reprodução de vídeo
- (IBAction)playControl:(id)sender;
- (IBAction)playPreview:(id)sender;
- (void)stopPreview;

// Pequisa de legendas
- (IBAction)subtitleSearch:(id)sender;
- (IBAction)iterateSearchResults:(id)sender;
- (IBAction)findSubtitle:(id)sender;

// Sincronismo
- (IBAction)syncPointsSelection:(id)sender;

// Funções
- (BOOL)saveSubtitlesAs:(NSURL*)url withFormat:(subtitleFileFormat)format;
@end
