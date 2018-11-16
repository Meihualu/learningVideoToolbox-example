//
//  ViewController.m
//  TYVideoToolbox_demo
//
//  Created by 汤义 on 2018/11/12.
//  Copyright © 2018年 汤义. All rights reserved.
//

#import "ViewController.h"
#import "TYCodingViewController.h"
#import "TYDecodingViewController.h"
#import "TYStyleCodecViewController.h"
#import "TYAudioCodingViewController.h"

@interface ViewController ()<UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) NSMutableArray *muArray;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self addTableView];
}

- (void)addTableView{
    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, W, H) style:UITableViewStylePlain];
    tableView.delegate = self;
    tableView.dataSource = self;
    [self.view addSubview:tableView];
}

- (NSMutableArray *)muArray{
    if (!_muArray) {
        _muArray = [[NSMutableArray alloc] init];
    }
    [_muArray addObject:@"编码"];
    [_muArray addObject:@"解码"];
    [_muArray addObject:@"编解吗"];
    [_muArray addObject:@"音频编码"];
    [_muArray addObject:@"音频解吗"];
    [_muArray addObject:@"音频编解吗"];
    return _muArray;
}

- (NSInteger)numberOfRowsInSection:(NSInteger)section{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return 6;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    static NSString *ID = @"cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:ID];
    }
    cell.textLabel.text = self.muArray[[indexPath row]];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    if (indexPath.row == 0) {
        TYCodingViewController *vc = [[TYCodingViewController alloc] init];
        [self.navigationController pushViewController:vc animated:YES];
    }else if(indexPath.row == 1){
        TYDecodingViewController *vc = [[TYDecodingViewController alloc] init];
        [self.navigationController pushViewController:vc animated:YES];
    }else if(indexPath.row == 2){
        TYStyleCodecViewController *vc = [[TYStyleCodecViewController alloc] init];
        [self.navigationController pushViewController:vc animated:YES];
    }else if(indexPath.row == 3){
        TYAudioCodingViewController *vc = [[TYAudioCodingViewController alloc] init];
        [self.navigationController pushViewController:vc animated:YES];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
