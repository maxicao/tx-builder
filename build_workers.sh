ROOT=$PWD/node_modules/monaco-editor/esm/vs
OPTS="--no-source-maps --log-level 1"        # Parcel options - See: https://parceljs.org/cli.html

yarn parcel build $ROOT/language/json/json.worker.js $OPTS
#yarn parcel build $ROOT/language/css/css.worker.js $OPTS
#yarn parcel build $ROOT/language/html/html.worker.js $OPTS
#yarn parcel build $ROOT/language/typescript/ts.worker.js $OPTS
yarn parcel build $ROOT/editor/editor.worker.js $OPTS