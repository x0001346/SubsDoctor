//
//  SubtitleListController.m
//  SubsDoctor
//
//  Created by Bruno Ferreira on 11/07/24.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "SubtitleListController.h"
#import "Subtitle.h"
#import <QTKit/QTMovie.h>

#include "math.h"

@implementation SubtitleListController



//NSString * movieExtensions[] = {@"avi", @"mkv", @"mov", @"mp4", @"mpg", @"wmv", @"rm"};
NSMutableArray *movieExtensions;
NSTimer *subtileSelectionTimer;


// Variáveis utilizadas na pesquisa
NSInteger lastSelectedSubtitle;   // Guarda o índice da última legenda selecionada antes de ter sido iniciada uma pesquisa
NSInteger lastFoundSubtitle;
bool searching;
bool changingCurrentSubtitle = FALSE;

// Variáveis utilizadas no sincronismo
float syncPointTime1, syncPointTime2;
NSInteger syncPoint1, syncPoint2;

// Variáveis utilizada na função Play Preview
QTTime playPreviewMovieTime;
float previewTime = 4;
NSInteger lastAutoSelectState;
BOOL playPreviewActive = FALSE;

NSURL *movieURL;
NSURL *subtitleURL;




- (void)updateSubtitleSelection
{
	static float lastMovieRate = 0;
	
	// Verifica se é necessário actualizar o botão de play
	float newMovieRate = [[movieView movie] rate];
	if (lastMovieRate != newMovieRate)
	{
		if (newMovieRate)
		{
			[playController setLabel:@"" forSegment:2];
		}
		else
		{
			[playController setLabel:@"" forSegment:2];
		}
		lastMovieRate = newMovieRate;
	}
		
	
    static QTTime lastMovieTime;
    QTTime currentMovieTime = [[movieView movie] currentTime];
    float currentTime = (float)(currentMovieTime.timeValue) / currentMovieTime.timeScale;
    
    // Verifica se a selecção automática das legendas está activa e o tempo actual do filme é diferente do tempo anterior
    if ([autoSelectButton state] != NSOffState && lastMovieTime.timeValue != currentMovieTime.timeValue)
    {
		if (changingCurrentSubtitle)
		{
			changingCurrentSubtitle = FALSE;
		}
		else
		{
			Subtitle *currentSubtitle;
			
			for (int i = 0; i < [subtitleList count]; i++)
			{
				currentSubtitle = [subtitleList objectAtIndex:i];
                
				if ((currentTime >= [currentSubtitle showTime])  && (currentTime <= ([currentSubtitle showTime] + [currentSubtitle period])))
				{
					[subtitleTableView scrollRowToVisible:i];
					NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:i];
					changingCurrentSubtitle = TRUE;
					[subtitleTableView selectRowIndexes:indexSet byExtendingSelection:NO];
					break;
				}
			}
		}
    }
    
    // Actualiza a apresentação do tempo actual do filme
    NSString *timeString;
    
    if (isnan(currentTime))
    {
        timeString = [Subtitle subtitleTimeToString:0];
    }
    else
    {
        timeString = [Subtitle subtitleTimeToString:currentTime];
    }
    
    [movieTimeField setStringValue:timeString];
    
    lastMovieTime = currentMovieTime;
}


- (IBAction)focusSubtitleTextEditor:(id)sender
{
    [appWindow makeFirstResponder:subtitleEditor];
}


- (id)init
{
    self = [super init];
    
    if (self)
    {
        subtitleList = [NSMutableArray arrayWithCapacity:500];
        syncPointTime1 = -1;
        syncPointTime2 = -1;

        movieExtensions = [NSMutableArray arrayWithObjects:@"avi", @"mov", @"mp4", @"mkv", nil];
        lastSelectedSubtitle = 0;
        searching = FALSE;
    }
    
    return self;
}


- (void)awakeFromNib
{
    [subtitleTableView setRowHeight:34];
    [subtitleTableView setTarget:self];
    [subtitleTableView setDoubleAction:@selector(focusSubtitleTextEditor:)];
    
    [NSApp activateIgnoringOtherApps:YES];
    
    subtileSelectionTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(updateSubtitleSelection) userInfo:nil repeats:YES];
	[syncPointsButtons setEnabled:FALSE];
}


- (void)clearSubtitleList
{
    [subtitleEditor setStringValue:@""];
    [showTimeField setStringValue:[Subtitle subtitleTimeToString:0]];
    [periodTimeField setStringValue:[NSString stringWithFormat:@"%0.3f", [NSNumber numberWithInt:0]]];
    [subtitleList removeAllObjects];
    [subtitleTableView reloadData];
}


/**
 *
 * @returns Em caso de sucesso devolve um número de segundos positivo, caso
 *          contrário devolve um valor negativo.
 */
-(float)parseTimeString:(NSString *)timeString
{
    float time;
    
    timeString = [timeString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSRange range = NSMakeRange(0, 2);
    
    time = [[timeString substringWithRange:range] intValue] * 3600;
    range.location = 3;
    time += [[timeString substringWithRange:range] intValue] * 60;
    range.location = 6;
    time += [[timeString substringWithRange:range] intValue];
    range.location = 9;
    range.length = 3;
    time += [[timeString substringWithRange:range] floatValue] / 1000;
    
    return time;
}


-(BOOL)parseSrtFromArray: (NSArray *)lines
{
    NSMutableString *currentSubtitleText = [NSMutableString stringWithCapacity:200];
    
    // Processa as linhas do ficheiro
    int lineBreakCounter = 0;
    int lineCounter = 0;
    
    Subtitle *currentSubtitle = [[Subtitle alloc] init];
    
    for (int line = 0; line < [lines count]; line++)
    {
        NSString *currentLine = [lines objectAtIndex:line];
        if ([currentLine length] == 0)
        {
            lineBreakCounter++;
            
            if (lineBreakCounter == 1)
            {
                [currentSubtitle setSubtitle:currentSubtitleText];
                [subtitleList addObject:currentSubtitle];
                lineCounter = 0;
            }
        }
        else
        {
            NSArray *showAndHideTimes;
            switch (lineCounter)
            {
                case 0: // Número da legenda
                    currentSubtitle = [[Subtitle alloc] init];
                    [currentSubtitleText setString:@""];
                    break;
                case 1: // Início / fim
                    showAndHideTimes = [currentLine  componentsSeparatedByString:@"-->"];
                    if ([showAndHideTimes count] != 2)
                    {
                        return FALSE;
                    }
                    
                    NSString *showTime = [showAndHideTimes objectAtIndex:0];
                    NSString *hideTime = [showAndHideTimes objectAtIndex:1];
                    
                    [currentSubtitle setShowTime:[self parseTimeString:showTime]];
                    float period = [self parseTimeString:hideTime] - [currentSubtitle showTime];
                    [currentSubtitle setPeriod:period];
                    break;
                case 2: // Legenda
                case 3:
                case 4:
                case 5:
                case 6:
                    if ([currentSubtitleText length] > 0)
                    {
                        [currentSubtitleText appendString:@"\r\n"];
                    }
                    [currentSubtitleText appendString:currentLine];
                    break;
                    
                default:
                    break;
            }
            
            lineCounter++;
            lineBreakCounter = 0;
        }
    }
    
    return TRUE;
}


- (IBAction)openFile:(id)sender
{
    NSOpenPanel *fileOpenDialog = [NSOpenPanel openPanel];
    [fileOpenDialog setCanChooseFiles:YES];
    [fileOpenDialog setCanChooseDirectories:NO];
    [fileOpenDialog setAllowsMultipleSelection:NO];
    [fileOpenDialog setAllowedFileTypes:[NSArray arrayWithObjects:@"srt", nil]];
    [fileOpenDialog runModal];
    
    if ([[fileOpenDialog URLs] count] != 1)
    {
        return;
    }
    
    NSString *fileName = [[[fileOpenDialog URLs] objectAtIndex:0] description];
    NSError *error = NULL;
    
    subtitleURL = [NSURL URLWithString:fileName];
    
    NSString *subtitleContent = [NSString stringWithContentsOfURL:subtitleURL encoding:NSWindowsCP1252StringEncoding error:&error];
    
    if (error)
    {
        NSAlert *alert = [NSAlert alertWithError:error];
        [alert runModal];
        subtitleURL = NULL;
        [saveMenu setEnabled:FALSE];
        return;
    }
    
    // Verifica se foi possível abrir o ficheiro
    if (subtitleContent)
    {
        [saveMenu setEnabled:TRUE];
        // Elimina eventuais legendas existentes
        [subtitleList removeAllObjects];
        
        NSArray *lines = [subtitleContent componentsSeparatedByString:@"\r\n"];
        
        if ([fileName hasSuffix:@".srt"])
        {
            [self parseSrtFromArray:lines];
        }
        
        [subtitleTableView reloadData];
        [subtitleTableView scrollRowToVisible:0];
        
        if ([subtitleList count] > 0)
        {
            [subtitleEditor setStringValue:[[subtitleList objectAtIndex:0] subtitle]];
            [showTimeField setStringValue:[[subtitleList objectAtIndex:0] showTimeAsString]];
            [periodTimeField setStringValue:[NSString stringWithFormat:@"%0.3f", [[subtitleList objectAtIndex:0] period]]];
        }
        
        // Procura um eventual ficheiro de vídeo associado
        NSURL *fileURLWithoutExtension = [subtitleURL URLByDeletingPathExtension];
        BOOL found = FALSE;
        
        for (NSString *movieExtension in movieExtensions)
        {
            movieURL = [fileURLWithoutExtension URLByAppendingPathExtension:movieExtension];
            
            NSError *error;
            
            [movieView setMovie:[QTMovie movieWithURL:movieURL error:nil]];
            
            if ([movieURL checkResourceIsReachableAndReturnError:&error])
            {
                [movieView setMovie:[QTMovie movieWithURL:movieURL error:nil]];
                NSString *windowTitle = [NSString stringWithFormat:@"Preview - %@", [movieURL lastPathComponent]];
                [previewWindow setTitle:windowTitle];
                // Encontrou um ficheiro de vídeo, sai
                found = TRUE;
                break;
            }
        }
        
        // Verifica se chegou ao fim da lista sem encontrar um ficheiro de vídeo.
        if (!found)
        {
            movieURL = NULL;
            [previewWindow setTitle:@"Preview"];
            [movieView setMovie:NULL];
			return;
        }
		
		// Activa os controlos
		[syncPointsButtons setEnabled:TRUE];
		[autoSelectButton setEnabled:TRUE];
		[playController setEnabled:TRUE];
		[playPreviewButton setEnabled:TRUE];
		[setSubtitleStartEndButtons setEnabled:TRUE];
		[previewWindow orderFront:self];
    }
}


- (BOOL)saveSubtitlesAs:(NSURL*)url withFormat:(subtitleFileFormat)format
{
    if (!url)
    {
        return FALSE;
    }
    
    NSString *subtitleContent = [[NSString alloc] init];
    int subtitleID = 1;
    
    for (Subtitle *currentSubtitle in subtitleList)
    {
        NSString *showTime = [currentSubtitle showTimeAsString];
        NSString *hideTime = [currentSubtitle hideTimeAsString];
        
        NSString * currentSubtitleText = [NSString stringWithFormat:@"%d\r\n%@ --> %@\r\n%@\r\n\r\n",subtitleID++, showTime, hideTime, [currentSubtitle subtitle]];
        subtitleContent = [subtitleContent stringByAppendingString:currentSubtitleText];
    }
    
    NSError *error = [[NSError alloc] init];
    
    if (![subtitleContent writeToURL:url atomically:true encoding:NSWindowsCP1252StringEncoding error:&error])
    {
        NSAlert *alert = [NSAlert alertWithError:error];
        [alert runModal];
        return FALSE;
    }
    else
    {
        QTTime currentTime;
        currentTime = [[movieView movie] currentTime];
        
        if (movieURL)
        {
            [movieView setMovie:[QTMovie movieWithURL:movieURL error:nil]];
            [[movieView movie] setCurrentTime:currentTime];
        }
    }
    
    return TRUE;
}


// Neste momento esta função foi copiada a partir da função saveFileAs, é necessário criar uma função
// que seja comum (deve receber o nome do ficheiro)
- (IBAction)saveFile:(id)sender
{
    [self saveSubtitlesAs:subtitleURL withFormat:sffSrt];
}


- (IBAction)saveFileAs:(id)sender
{
    NSSavePanel *fileSaveDialog = [NSSavePanel savePanel];
    [fileSaveDialog setAllowedFileTypes:[NSArray arrayWithObjects:@"srt", nil]];
    [fileSaveDialog runModal];
    
    if ([self saveSubtitlesAs:[fileSaveDialog URL] withFormat:sffSrt])
    {
        subtitleURL = [fileSaveDialog URL];
    }
}

    
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    if (subtitleList)
    {
        return [subtitleList count];
    }
    
    return 0;
}


- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSString *columnName = [tableColumn identifier];
    
    Subtitle *currentSubtitle = [subtitleList objectAtIndex:row];
    
    if ([columnName isEqualToString:@"number"])
    {
        return [NSString stringWithFormat:@"%d", row + 1];
    }
    else if ([columnName isEqualToString:@"showTime"])
    {
        return [currentSubtitle showTimeAsString];
    }
    else if ([columnName isEqualToString:@"hide"])
    {
        return [currentSubtitle hideTimeAsString];
    }
    else if ([columnName isEqualToString:@"subtitle"])
    {
        return [currentSubtitle subtitle];
    }
    else if ([columnName isEqualToString:@"rate"])
    {
        return  [NSString stringWithFormat:@"%d", row % 4];
    }
    
    return @"?";
}


/**
 * Funções de verificação de consistência
 */
-(void)checkTiming
{
    float lastTime = 0;
    
    for (int i = 0; i < [subtitleList count]; i++)
    {
        Subtitle *currentSubtitle = [subtitleList objectAtIndex:i];
        
        // Verifica se o tempo de início da legenda é inválido
        if (lastTime < [currentSubtitle showTime])
        {
            [currentSubtitle setHasInvalidStartTime:TRUE];
        }
        else
        {
            [currentSubtitle setHasInvalidStartTime:FALSE];
        }
        
        lastTime = [currentSubtitle showTime] + [currentSubtitle period];
    }
}


-(IBAction)changeSubtitleText:(id)sender
{
    NSInteger currentSubtitle = [subtitleTableView selectedRow];
    
    if (currentSubtitle >= 0)
    {
        [[subtitleList objectAtIndex:currentSubtitle] setSubtitle:[subtitleEditor stringValue]];
        [subtitleTableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:currentSubtitle] columnIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 3)]];
    }
}


- (IBAction)changeSubtitleShowTime:(id)sender
{
    NSInteger currentSubtitle = [subtitleTableView selectedRow];
    
    if (currentSubtitle >= 0)
    {
        [[subtitleList objectAtIndex:currentSubtitle] setShowTime:[self parseTimeString:[showTimeField stringValue]]];
        [subtitleTableView reloadData];
    }
}


- (IBAction)changeSubtitlePeriodTime:(id)sender
{
    NSInteger currentSubtitle = [subtitleTableView selectedRow];
    
    if (currentSubtitle >= 0)
    {
        float period = [periodTimeField floatValue];
        [[subtitleList objectAtIndex:currentSubtitle] setPeriod:period];
        [periodTimeField setStringValue:[NSString stringWithFormat:@"%.3f", period]];
        [subtitleTableView reloadData];
    }
}


- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	if ([autoSelectButton state] == NSOffState)
	{
		return;
	}
	
	// Verifica se existe uma legenda selecionada
	if ([subtitleList count] > 0 && [subtitleTableView selectedRow] >= 0)
	{
		Subtitle *currentSubtitle = [subtitleList objectAtIndex:[subtitleTableView selectedRow]];
		[subtitleEditor setStringValue:[currentSubtitle subtitle]];
		[showTimeField setStringValue:[currentSubtitle showTimeAsString]];
		[periodTimeField setStringValue:[NSString stringWithFormat:@"%.3f", [currentSubtitle period]]];
			
		if (!changingCurrentSubtitle)
		{
			[[movieView movie] setCurrentTime:QTMakeTime([currentSubtitle showTime] * 1000, 1000)];
		}
		changingCurrentSubtitle = !changingCurrentSubtitle;
	}
	else
	{
		[subtitleEditor setStringValue:@""];
		[showTimeField setStringValue:[Subtitle subtitleTimeToString:0]];
		[periodTimeField setStringValue:[NSString stringWithFormat:@"%0.3f", [NSNumber numberWithInt:0]]];
	}
        
}



- (IBAction)addRemoveSubtitle:(id)sender
{
    NSInteger subtitleIndex = [subtitleTableView selectedRow];

    switch ([sender selectedSegment])
    {
        case 0: // Remover legenda
            if (subtitleIndex >= 0)
            {
                [subtitleList removeObjectAtIndex:subtitleIndex];
                [subtitleTableView reloadData];
            }
            break;
        case 1: // Adicionar legenda
            if (subtitleIndex >= 0)
            {
                [subtitleList insertObject:[[Subtitle alloc] init] atIndex:subtitleIndex + 1];
            }
            else
            {
                [subtitleList addObject:[[Subtitle alloc] init]];
            }
            [subtitleTableView reloadData];
                
            break;
        default:
            break;
    }
}


- (IBAction)newSubtitle:(id)sender
{
    NSAlert *alert = [[NSAlert alloc] init];
    
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert setMessageText:@"Clear current subtitle?"];
    [alert setAlertStyle:NSWarningAlertStyle];

    [alert beginSheetModalForWindow:appWindow modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];    
}


- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSAlertFirstButtonReturn)
    {
        [self clearSubtitleList];
    }
}


- (IBAction)playControl:(id)sender
{
    QTTime movieTime;
    QTTime timeStep = QTMakeTime(STEP_PERIOD, 1);

    switch ([sender selectedSegment])
    {
        case 0: // Rewind
            [movieView gotoBeginning:self];
            break;
        case 1: // Step backward
            movieTime = [[movieView movie] currentTime];
            movieTime = QTTimeDecrement(movieTime, timeStep);
            [[movieView movie] setCurrentTime:movieTime];
            break;
        case 2: // Play / Pause
            // Verifica se o filme está parado
            if ([[movieView movie] rate] == 0)
            {
                [movieView play:self];
				[previewWindow orderFront:self];
				[playPreviewButton setEnabled:FALSE];
				[syncPointsButtons setEnabled:FALSE];
				[setSubtitleStartEndButtons setEnabled:FALSE];
            }
            else
            {
                [movieView pause:self];
				[playPreviewButton setEnabled:TRUE];
				[syncPointsButtons setEnabled:TRUE];
				[setSubtitleStartEndButtons setEnabled:TRUE];
            }
            break;
        case 3: // Step forward
            movieTime = [[movieView movie] currentTime];
            movieTime = QTTimeIncrement(movieTime, timeStep);
            [[movieView movie] setCurrentTime:movieTime];
            break;
        case 4: // End
            [movieView gotoEnd:self];
            break;
        default:
            break;
    }
}


- (IBAction)playPreview:(id)sender
{
    // Verifica se a função play preview já se encontra activa
    if (playPreviewActive)
    {
		// Para a reprodução do filme
		[[movieView movie] stop];
		[[movieView movie] setCurrentTime:playPreviewMovieTime];
		
		// Desactiva o botão de play preview
		[playPreviewButton setState:NSOffState];
		playPreviewActive = FALSE;
		
		// Repõe o estado anterior do botão auto select
		[autoSelectButton setState:lastAutoSelectState];
		
		// Repõe a posição anterior do filme
		[[movieView movie] setCurrentTime:playPreviewMovieTime];

		// Repõe o estado anterior do botão auto select
		[autoSelectButton setState:lastAutoSelectState];
		
		// Actualiza o estado de activação dos botões
        [syncPointsButtons setEnabled:TRUE];
        [playController setEnabled:TRUE];
		[autoSelectButton setEnabled:TRUE];
		[setSubtitleStartEndButtons setEnabled:TRUE];
    }
    else
    {
        // Guarda o estado actual da função auto select
        lastAutoSelectState = [autoSelectButton state];
        [autoSelectButton setState:NSOffState];
        
		// Guarda a posição actual 
        playPreviewMovieTime = [[movieView movie] currentTime];
        [[movieView movie] play];
        playPreviewActive = TRUE;
        
        // Desactiva os restantes botões
        [syncPointsButtons setEnabled:FALSE];
        [playController setEnabled:FALSE];
        [autoSelectButton setEnabled:FALSE];
		[setSubtitleStartEndButtons setEnabled:FALSE];
    }
}


- (IBAction) showTimeStepper:(id)sender
{
}


- (IBAction) durationTimeStepper:(id)sender
{
}


- (IBAction)setStartEndTime:(id)sender
{
    // Verifica se existe um legenda selecionada
    if ([subtitleTableView selectedRow] >= 0)
    {
		float currentMovieTime = (float)[[movieView movie] currentTime].timeValue / [[movieView movie] currentTime].timeScale;
		Subtitle *currentSubtitle = [subtitleList objectAtIndex:[subtitleTableView selectedRow]];
		switch ([sender selectedSegment]) 
		{
			case 0:// Mostrar legenda
				[currentSubtitle setShowTime:currentMovieTime];
				break;
			case 1:// Ocultar legenda
				if (currentMovieTime > [currentSubtitle showTime])
				{
					[currentSubtitle setPeriod:currentMovieTime - [currentSubtitle showTime]];
				}
				else
				{
					NSAlert *alert = [NSAlert alertWithMessageText:@"Invalid hide time." defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"The hide time of the subtitle should be after the show time."];
					[alert runModal];
				}
				break;
			default:
				return;
		}
		[subtitleList sortUsingComparator:^(id obj1, id obj2) {
			if ([obj1 showTime] > [obj2 showTime])
				return (NSComparisonResult)NSOrderedDescending;
			else
				return (NSComparisonResult)NSOrderedAscending;
		} ];
		
		[subtitleTableView reloadData];
    }
}


- (IBAction)subtitleSearch:(id)sender
{
    // Verifica se a pesquisa foi iniciada agora
    if ([[searchField stringValue] length] > 0)
    {
        if (!searching)
        {
            // Guarda o índice da legenda actualmente selecionada
            lastSelectedSubtitle = [subtitleTableView selectedRow];
            lastFoundSubtitle = 0;
            searching = TRUE;
        }
        
        int subtitleIndex = 0;
        
        
        for (Subtitle *currentSubtitle in subtitleList)
        {
            if ([[currentSubtitle subtitle] rangeOfString:[searchField stringValue] options:NSCaseInsensitiveSearch].location != NSNotFound)
            {
                [subtitleTableView scrollRowToVisible:subtitleIndex];
                
                NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:subtitleIndex];
                [subtitleTableView selectRowIndexes:indexSet byExtendingSelection:NO];
                lastFoundSubtitle = subtitleIndex;
                break;
            }
            
            subtitleIndex++;
        }
    }
    else
    {
        // A pesquisa terminou, repõe a última legenda selecionda
        searching = FALSE;
        if (lastSelectedSubtitle < 0)
        {
            NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:0];
            [subtitleTableView selectRowIndexes:indexSet byExtendingSelection:NO];
        }
        else
        {
            NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:lastSelectedSubtitle];
            [subtitleTableView selectRowIndexes:indexSet byExtendingSelection:NO];
        }
        
    }
}


- (IBAction)findSubtitle:(id)sender;
{
    [searchField becomeFirstResponder];
}


- (IBAction)iterateSearchResults:(id)sender
{
    bool subtitleFound = FALSE;
    Subtitle *currentSubtitle;
    
    switch ([sender selectedSegment])
    {
        case 0: // Procurar legenda anterior
            for (NSInteger i = lastFoundSubtitle - 1; i > 0; i--)
            {
                currentSubtitle = [subtitleList objectAtIndex:i];
                
                if ([[[subtitleList objectAtIndex:i] subtitle] rangeOfString:[searchField stringValue] options:NSCaseInsensitiveSearch].location != NSNotFound)
                {
                    [subtitleTableView scrollRowToVisible:i];
                    
                    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:i];
                    [subtitleTableView selectRowIndexes:indexSet byExtendingSelection:NO];
                    lastFoundSubtitle = i;
                    subtitleFound = TRUE;
                    break;
                }
            }
            break;
        case 1: // Procurar legenda seguinte a partir da última legenda encontrada
            for (NSInteger i = lastFoundSubtitle + 1; i < [subtitleList count]; i++)
            {
                currentSubtitle = [subtitleList objectAtIndex:i];
                
                if ([[currentSubtitle subtitle] rangeOfString:[searchField stringValue] options:NSCaseInsensitiveSearch].location != NSNotFound)
                {
                    [subtitleTableView scrollRowToVisible:i];
                    
                    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:i];
                    [subtitleTableView selectRowIndexes:indexSet byExtendingSelection:NO];
                    lastFoundSubtitle = i;
                    subtitleFound = TRUE;
                    break;
                }
            }
            
            break;
        default:
            break;
    }
    
    if (!subtitleFound)
    {
        [(NSSound *)[NSSound soundNamed:@"Funk"] play];
    }
}


- (IBAction)syncPointsSelection:(id)sender
{
    QTTime currentTime = [[movieView movie] currentTime];
    float currentFloatTime = (float)currentTime.timeValue / currentTime.timeScale;
    
    switch ([sender selectedSegment])
    {
        case 0: // Ponto de sincronismo 1
            if (syncPointTime1 < 0)
            {
                syncPoint1 = [subtitleTableView selectedRow];
                syncPointTime1 = currentFloatTime;
                [syncPointsButtons setSelected:TRUE forSegment:0];
            }
            else
            {
                syncPointTime1 = -1;
                [syncPointsButtons setSelected:FALSE forSegment:0];
            }
            break;
        case 1: // Ponto de sincronismo 2
            if (syncPointTime2 < 0)
            {
                syncPoint2 = [subtitleTableView selectedRow];
                syncPointTime2 = currentFloatTime;
                [syncPointsButtons setSelected:TRUE forSegment:1];
            }
            else
            {
                syncPointTime2 = -1;
                [syncPointsButtons setSelected:FALSE forSegment:1];
            }
            break;
            break;
    }
    
    // Verifica se foram selecionados dois pontos de sincronismo
    if (syncPointTime1 >= 0 && syncPointTime2 >= 0)
    {
        // Verifica se o primeiro ponto de sincronismo é após o segundo
        if ((syncPointTime1 >= syncPointTime2) && (syncPointTime2 > 0))
        {
            NSAlert *alert = [NSAlert alertWithMessageText:@"The second sync point must be later than the first." defaultButton:@"OK" alternateButton:NULL otherButton:NULL informativeTextWithFormat:@""];
            [alert runModal];
            [syncPointsButtons setSelected:FALSE forSegment:0];
            [syncPointsButtons setSelected:TRUE forSegment:1];
            return;
        }
        
        
        // Foram definidos pontos de sincronismo
        if (syncPointTime1 != syncPointTime2)
        {
            Subtitle *subtitle1 = [subtitleList objectAtIndex:syncPoint1];
            Subtitle *subtitle2 = [subtitleList objectAtIndex:syncPoint2];
            float ratio = (syncPointTime2 - syncPointTime1) / ([subtitle2 showTime] - [subtitle1 showTime]);
            float offset = syncPointTime1 - ([[subtitleList objectAtIndex:syncPoint1] showTime] * ratio);
            NSString *dialogMessage = [NSString stringWithFormat:@"Are you shure you want to synchronize current subtitles using the specified settings?"];
            NSAlert *alert = [NSAlert alertWithMessageText:dialogMessage defaultButton:@"Yes" alternateButton:@"No" otherButton:NULL informativeTextWithFormat:@""];
            [alert runModal];
            
            [syncPointsButtons setSelected:FALSE forSegment:0];
            [syncPointsButtons setSelected:FALSE forSegment:1];
            
            if ([[[alert buttons] objectAtIndex:0] state] == 1)
            {
                // Ajusta as legendas
            
                for (Subtitle *currentSubtitle in subtitleList)
                {
                    [currentSubtitle setShowTime:[currentSubtitle showTime] * ratio + offset]; 
                    [currentSubtitle setPeriod:[currentSubtitle period] * ratio]; 
                }
                [subtitleTableView reloadData];
            }
            syncPointTime1 = -1;
            syncPointTime2 = -1;
        }
    }
}


@end
