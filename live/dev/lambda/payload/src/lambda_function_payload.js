exports.handler = async (event, context) => {
    // TODO implement
    console.log('Context: ' + JSON.stringify(context));
    const response = {
        statusCode: 200,
        body: JSON.stringify({
            message: 'Hello from Lambda!',
            event: event,
            context: context
        }),
    };
    return response;
};

// exports.test = function(event, context) {
//   console.log("EVENT: \n" + JSON.stringify(event, null, 2));
//   console.log("process.env...\n" + process.env);
//   return context.logStreamName;
// }

// // exports.test = async function(event, context) {
// //   console.log("EVENT: \n" + JSON.stringify(event, null, 2))
// //   console.log("process.env...\n" + process.env)
// //   return context.logStreamName
// // }
