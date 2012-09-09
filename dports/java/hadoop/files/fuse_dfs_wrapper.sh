#
# Copyright 2005 The Apache Software Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

if [ "$HADOOP_HOME" = "" ]; then
export HADOOP_HOME=@hadoop_home@
fi

for f in ls $HADOOP_HOME/lib/*.jar $HADOOP_HOME/*.jar ; do
export  CLASSPATH=$CLASSPATH:$f
done

if [ "$JAVA_HOME" = "" ]; then
export  JAVA_HOME=@java_home@
fi

@prefix@/bin/fuse_dfs $@
