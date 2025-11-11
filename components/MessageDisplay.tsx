
import React, { useEffect, useRef } from 'react';
import { ChatMessage as ChatMessageType } from '../types';
import ChatMessage from './ChatMessage';

interface MessageDisplayProps {
    messages: ChatMessageType[];
    isLoading: boolean;
}

const LoadingIndicator: React.FC = () => (
    <div className="flex justify-start">
        <div className="bg-gray-700 rounded-lg p-3 max-w-lg">
            <div className="flex items-center space-x-2 rtl:space-x-reverse">
                <div className="w-2 h-2 bg-gray-400 rounded-full animate-bounce [animation-delay:-0.3s]"></div>
                <div className="w-2 h-2 bg-gray-400 rounded-full animate-bounce [animation-delay:-0.15s]"></div>
                <div className="w-2 h-2 bg-gray-400 rounded-full animate-bounce"></div>
            </div>
        </div>
    </div>
);

const MessageDisplay: React.FC<MessageDisplayProps> = ({ messages, isLoading }) => {
    const endOfMessagesRef = useRef<HTMLDivElement>(null);

    useEffect(() => {
        endOfMessagesRef.current?.scrollIntoView({ behavior: 'smooth' });
    }, [messages, isLoading]);

    return (
        <main className="flex-1 overflow-y-auto p-4 md:p-6 space-y-6">
            {messages.map((msg, index) => (
                <ChatMessage key={index} message={msg} />
            ))}
            {isLoading && <LoadingIndicator />}
            <div ref={endOfMessagesRef} />
        </main>
    );
};

export default MessageDisplay;
