import boto3
#import json
#import docopt

def get_messages_from_queue(queue_url):
    sqs_client = boto3.client('sqs')
    messages = []
    resp = sqs_client.receive_message(
    QueueUrl='https://sqs.ap-southeast-2.amazonaws.com/353014893181/aft-account-request-dlq.fifo',
    AttributeNames=['All'],
    MaxNumberOfMessages=1
    )
    print(resp)
    while 1==1:
        print('yes')
        resp = sqs_client.receive_message(
            QueueUrl='https://sqs.ap-southeast-2.amazonaws.com/353014893181/aft-account-request-dlq.fifo',
            AttributeNames=['All'],
            MaxNumberOfMessages=10
        )
        print(sqs_client)
        
        try:
            messages.extend(resp['Messages'])
        except KeyError:
            break
        entries = [
            {'Id': msg['MessageId'], 'ReceiptHandle': msg['ReceiptHandle']}
            for msg in resp['Messages']
        ]
        resp = sqs_client.delete_message_batch(
            QueueUrl=queue_url, Entries=entries
        )
        if len(resp['Successful']) != len(entries):
            raise RuntimeError(
                f"Failed to delete messages: entries={entries!r} resp={resp!r}"
            )
    print("print")
    return messages
# if __name__ == '__main__':
#     args = docopt.docopt(__doc__)
#     queue_url = args['<QUEUE_URL>']
#     for message in get_messages_from_queue(queue_url):
#         print(json.dumps(message))
