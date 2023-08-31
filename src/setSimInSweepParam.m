function simInArray_out = setSimInSweepParam(simInArray_in, paramToSweepTable, paramPrefix)
% 为 SimulationInput 对象数组设置扫描参数
% simInArray_in      输入 SimulationInput 对象数组
% paramToSweepTable  待扫描的参数表格，行名为参数名，需要包含变量 "min" "max" "step"
% paramPrefix        参数名前缀，当前版本以在参数变量前加此前缀来区分算法参数

simInArray_out = simInArray_in;

% 为扫描参数建数据表 paramSweepValueTable，保存用户设置的参数组
paramSweepValueArray = {0; 0; 0; 0; 0};
rowNameArray = {'row_1', 'row_2', 'row_3', 'row_4', 'row_5'};

for rowNum = 1:height(paramToSweepTable)
    paramSweepValueArray(rowNum) = {paramToSweepTable(rowNum, :).min: ...
                                        paramToSweepTable(rowNum, :).step ...
                                        :paramToSweepTable(rowNum, :).max};
    rowNameArray(rowNum) = paramToSweepTable.Properties.RowNames(rowNum);
end

paramSweepValueTable = table(paramSweepValueArray, ...
    'RowName', rowNameArray);

simInIndex = 1;

for inner1 = 1:length(paramSweepValueTable(1, :).paramSweepValueArray{1})
    for inner2 = 1:length(paramSweepValueTable(2, :).paramSweepValueArray{1})
        for inner3 = 1:length(paramSweepValueTable(3, :).paramSweepValueArray{1})
            for inner4 = 1:length(paramSweepValueTable(4, :).paramSweepValueArray{1})
                for inner5 = 1:length(paramSweepValueTable(5, :).paramSweepValueArray{1})

                    % 使用"基于变量生成字段名称"技巧，在更内一层循环中
                    % 用 pIndexStruct.(['inner', num2str(paramIndex)])
                    % 拼接出真正需要的索引值
                    pIndexStruct.inner1 = inner1;
                    pIndexStruct.inner2 = inner2;
                    pIndexStruct.inner3 = inner3;
                    pIndexStruct.inner4 = inner4;
                    pIndexStruct.inner5 = inner5;

                    for paramIndex = 1:height(paramToSweepTable)
                        % 此层循环实际执行次数只由扫描参数个数决定

                        variableName = [paramPrefix, ...
                            paramToSweepTable.Properties.RowNames{paramIndex}];

                        pIndex = pIndexStruct.(['inner', ...
                            num2str(paramIndex)]);
                        paramValue = paramSweepValueTable( ...
                            paramIndex, :).paramSweepValueArray{1}( ...
                            pIndex);

                        simInArray_out(simInIndex) = simInArray_in(simInIndex).setVariable( ...
                            variableName, paramValue, 'Workspace', ...
                            simInArray_in(1).ModelName);

                    end

                    simInIndex = simInIndex + 1;
                end
            end
        end
    end
end
end
