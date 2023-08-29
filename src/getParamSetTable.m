function [paramSetTable] = getParamSetTable(simIn, paramNameArray, paramPrefix)
% 从 Simulink.SimulationInput 数组对象中读取并解析参数组表格
% simIn              SimulationInput 数组
% paramNameArray     由参数名组成的字符串数组
% paramPrefix        参数名前缀，以此识别哪些模块为参数

% FIXME 已知问题：只能获取全为 doble 类型的参数值
paramSetTable = array2table(zeros([length(simIn), length(paramNameArray)]));
paramSetTable.Properties.VariableNames = paramNameArray;

RowNameArray = strings;

for index = 1:length(simIn)
    
    for variableIndex = 1:length(simIn(index).Variables)
        variableName = simIn(index).Variables(variableIndex).Name;
        
        if startsWith(variableName, paramPrefix)
            paramName = erase(variableName, paramPrefix);
            
            paramSetTable(index, paramName) = ...
                {simIn(index).Variables(variableIndex).Value};
        end
        
    end
    
    RowNameArray(index) = num2str(index);
end

paramSetTable.Properties.RowNames = RowNameArray';
end
