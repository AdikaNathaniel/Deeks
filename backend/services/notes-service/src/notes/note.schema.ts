import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type NoteDocument = Note & Document;

@Schema({ timestamps: true })
export class Note {
  @Prop({ required: true, index: true })
  userId!: string;

  @Prop({ required: true })
  title!: string;

  @Prop({ default: '' })
  body!: string;

  @Prop({ type: [String], default: [] })
  tags!: string[];

  @Prop()
  sourceImageRef?: string;
}

export const NoteSchema = SchemaFactory.createForClass(Note);
